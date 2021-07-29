# fias

## Скачивание и обработка данных
Данные лучше скачивать в формате .dbf, т.к такой формат читается напрямую библиотекой geopandas. Загружать лучше в PostgreSQL, т.к функции обработки написаны именно там.

Скачать последнюю версию ФИАС можно тут: https://fias.nalog.ru/Updates.aspx. Скачивать нужно .dbf файл который не delta.

После загрузки, нужно разархивировать, у нас на сервере это можно сделать с помощью команды: 

```bash
unrar e fias_dbf.rar
```
Распакованные файлы делятся на категории:

1. ADDROB__.DBF - Файлы с адресообразующими элементами (Вместо __ - номер субъекта РФ). (Связан сам с собой связкой ADDROB.AOGUID = ADDROB.PARENTGUID для тех адресообразующих элементов, которые не вершина (у которых есть родители).
2. HOUSE__.DBF - Файлы с домами. (Связан с родительским адресообразующим элементом связкой ADDROB.AOGUID = HOUSE.AOGUID)
3. STEAD__.DBF - Файлы с участками. (Связан с родительским адресообразующим элементом связкой ADDROB.AOGUID = STEAD.PARENTGUID)
4. ROOM__.DBF - Файлы с помещениями. (Связан с родительским домом связкой ROOM.HOUSEGUID = HOUSE.HOUSEGUID).
5. Другие файлы, с расшифровкой статусных полей

Далее, любой из файлов можно считать питоном следующим образом:


<details><summary>Считывание файла и загрузка в базу</summary>
<p>

```python
import geopandas as gpd
from core.database.db import DB

for nm in ['addrob', 'house', 'stead', 'room', 'nordoc']:
    gdf = gpd.read_file('%s%s.DBF' % (nm.upper(), city_id), encoding='cp866')
    gdf.columns = [x.lower() for x in gdf.columns]
    gdf.drop('geometry', axis=1, inplace=True)
    db = DB(db='fias')
    db.copy(gdf, table=nm)
```

</p>
</details>

## Преобразование данных и сбор адреса в строчку

Изначально, сбор адресов происходил в соответствии с этими статьями на хабре:

1. https://habr.com/ru/post/316314/  (1 часть)
2. https://habr.com/ru/post/316380/  (2 часть)
3. https://habr.com/ru/post/316622/  (3 часть)
4. https://habr.com/ru/post/316856/  (4 часть)

Потом функции были слегка дополнены (однако этому чуваку большое спасибо), и они находятся в этом репозитории.

### Функции работают следующим образом:

1. fstf_addressobjects_addressobjecttree(guid) - по GUID (AOGUID, PARENTGUID) собирает дерево адресов в формате - самый старший родитель → самый младший ребенок
2. fsfn_addressobjects_treeactualname(guid, mask) - по GUID и Маске собирает адрес в одну строку. Подробнее о масках можно посмотреть в голове кода
3. fsfn_addressobjects_objectgroup(guid) - вспомогательная функция которая по GUID распознает уровень элемента. 

### Примеры использования:

<details><summary>Пример</summary>
<p>
  
```sql
select fstf_addressobjects_addressobjecttree('c63f847c-6415-4427-8fba-f1984419f404')
select * from fsfn_addressobjects_treeactualname('c63f847c-6415-4427-8fba-f1984419f404', '{TM,TP,LM,LP,LP2,ST}')
```

</p>
</details>

В итоге, эти функции использовались для того, чтобы подтянуть к HOUSE и STEAD читаемые адреса. (Желательно на addrob.aoguid и addrob.aoid навесить btree, иначе очень долго будет запрос работать)

Формирование строчек адреса для разных таблиц:

<details><summary>Формирование строчек адреса для разных таблиц</summary>
<p>

```sql
create table house_with_addresses as
(
select fsfn_addressobjects_treeactualname(aoguid, '{TM,TP,LM,LP,LP2,ST}') as address,
       fsfn_addressobjects_treeactualname(aoguid, '{TM}') as state,
       fsfn_addressobjects_treeactualname(aoguid, '{TP}') as district,
       fsfn_addressobjects_treeactualname(aoguid, '{LM}') as city,
       fsfn_addressobjects_treeactualname(aoguid, '{LP}') as county,
       fsfn_addressobjects_treeactualname(aoguid, '{LP2}') as sub_county,
       fsfn_addressobjects_treeactualname(aoguid, '{ST}') as street,
       h.*,
	   nd.*,
	   hs."NAME" as house_status,
	   es.name as est_status
from house h
left join nordoc nd on nd.normdocid = h.normdoc
left join hststat hs on hs."HOUSESTID" = h.statstatus
left join eststat es on es."eststatid" = h.eststatus
where h.enddate::date > now()
)

create table stead_with_addresses as
(
select fsfn_addressobjects_treeactualname(parentguid, '{TM,TP,LM,LP,LP2,ST}') as address,
       fsfn_addressobjects_treeactualname(parentguid, '{TM}') as state,
       fsfn_addressobjects_treeactualname(parentguid, '{TP}') as district,
       fsfn_addressobjects_treeactualname(parentguid, '{LM}') as city,
       fsfn_addressobjects_treeactualname(parentguid, '{LP}') as county,
       fsfn_addressobjects_treeactualname(parentguid, '{LP2}') as sub_county,
       fsfn_addressobjects_treeactualname(parentguid, '{ST}') as street,
       s.*,
	   nd.*
from stead s
left join nordoc nd on nd.normdocid = s.normdoc
where s.enddate::date > now()
)

create table room_with_addresses as 
(
select h.address, h.state, h.district, h.city, h.county, h.sub_county, h.street, h.housenum,
	r.*,
	nd.*
from room as r 
left join house_with_addresses as h on h.houseguid = r.houseguid
left join nordoc nd on nd.normdocid = r.normdoc
where r.enddate::date > now() and h.enddate::date > now()
)
```

</p>
</details>

Так же есть скрипт по разделению адресов на юниты, он вот такой:

<details><summary>Разделение адресов на юниты</summary>
<p>

```python
import pandas as pd
import sys
import re
from core.database.db import DB


def divide_addresses(df):
    """
    Function divides address into subunits
    Args:
        df: dataframe with columns ['city', 'county', 'street', 'sub_county']

    Returns:
        df contains all columns that it had before, with new ones with address subunits
    """
    df['city_type'] = df['city'].map(lambda x: x.split(' ')[0])
    df['city_name'] = df.apply(lambda x: x['city'].lstrip(x['city_type'] + ' '), axis=1)
    # Вырезаем тип нас. пункта
    df['county_type'] = df['county'].map(lambda x: x.split(' ')[0])
    # Вырезаем название сельсовета
    df['selsovet'] = df['county'].map(lambda x: x.split('(')[1].split('с/с')[0] if 'с/с' in x or 'С/С' in x else '')

    # Вырезаем название нас. пункта
    df['county_name'] = df.apply(lambda x: x['county'].lstrip(x['county_type'] + ' '), axis=1)
    # Убираем из названия нас. пункта всё что в скобках
    df['county_name'] = df['county_name'].map(lambda x: re.sub(r'\([^)]*\)', '', x))
    df['street_type'] = df['street'].map(lambda x: x.split(' ')[0])
    df['street_name'] = df.apply(lambda x: x['street'].lstrip(x['street_type']), axis=1)
    df['sub_county_type'] = df['sub_county'].map(lambda x: x.split(' ')[0])
    df['sub_county_name'] = df.apply(lambda x: x['sub_county'].lstrip(x['sub_county_type']), axis=1)
    return df

```

</p>
</details>
