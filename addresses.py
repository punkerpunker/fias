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
