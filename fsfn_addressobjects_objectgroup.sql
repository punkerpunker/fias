-- FUNCTION: public.fsfn_addressobjects_objectgroup(character varying, integer)

-- DROP FUNCTION public.fsfn_addressobjects_objectgroup(character varying, integer);

CREATE OR REPLACE FUNCTION public.fsfn_addressobjects_objectgroup(
	a_aoguid character varying,
	a_currstatus integer DEFAULT NULL::integer)
    RETURNS character varying
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE 
AS $BODY$
DECLARE
	c_CountryGroupValue   CONSTANT VARCHAR(50):='Country';
	c_RegionGroupValue	    CONSTANT VARCHAR(50):='Region';
	c_CityGroupValue          CONSTANT VARCHAR(50):='City';
	c_TerritoryGroupValue  CONSTANT VARCHAR(50):='Territory';
	c_LocalityGroupValue   CONSTANT VARCHAR(50):='Locality';
	c_MotorRoadValue        CONSTANT VARCHAR(50):='MotorRoad';
	c_RailWayObjectValue  CONSTANT VARCHAR(50):='RailWayObject';
	c_VillageCouncilValue  CONSTANT VARCHAR(50):='VillageCouncil';
	c_StreetGroupValue       CONSTANT VARCHAR(50):='Street';
	c_AddlTerritoryValue    CONSTANT VARCHAR(50):='AddlTerritory';
	c_PartAddlTerritoryValue CONSTANT VARCHAR(50):='PartAddlTerritory';
	v_ShortTypeName         VARCHAR(10);   /* Тип адресообразующего элемента */ 
	v_AddressObjectName  VARCHAR(100); /* Название адресообразующего элемента */ 
	v_AOLevel                     INTEGER;    /* Уровень адресообразующего элемента*/	
	v_CurrStatus                  INTEGER;    /* Текущий статус адресообразующего элемента*/
	v_ObjectGroup              VARCHAR(50);   /* Группа адресообразующего элемента	*/
 	v_Return_Error		Integer :=0;	/* Код возврата */
--**************************************************************************       
--**************************************************************************
 BEGIN
     SELECT INTO v_CurrStatus COALESCE(a_CurrStatus,MIN(addrobj.currstatus)) 
                     FROM addrob as addrobj WHERE addrobj.AOGUID=a_AOGUID;
     SELECT INTO v_ShortTypeName,v_AddressObjectName,v_AOLevel
                                 ShortName,FormalName,AOLevel 
                     FROM addrob as addrobj   
                     WHERE addrobj.AOGUID=a_AOGUID AND addrobj.currstatus = v_CurrStatus 	
                     LIMIT 1;
     IF v_AOLevel = 1 AND UPPER(v_ShortTypeName) <> 'Г' THEN /*  уровень региона */ 
          v_ObjectGroup:=c_RegionGroupValue;
     ELSIF v_AOLevel = 1 AND UPPER(v_ShortTypeName) =  'Г' THEN /*  уровень города */
                                                     /* как региона  */ 
          v_ObjectGroup:=c_CityGroupValue;
     ELSIF v_AOLevel = 3 THEN /* уровень района */
          v_ObjectGroup:=c_TerritoryGroupValue;
      ELSIF (v_AOLevel = 4 AND UPPER(v_ShortTypeName) NOT IN ('С/С','С/А','С/О','С/МО')) 
                OR (v_AOLevel = 1 AND UPPER(v_ShortTypeName) <> 'Г')  THEN /* уровень города */ 
          v_ObjectGroup:=c_CityGroupValue;
      ELSIF v_AOLevel IN (4,6)  AND UPPER(v_ShortTypeName) IN ('С/С','С/А','С/О','С/МО') 
               AND UPPER(v_ShortTypeName) NOT LIKE ('Ж/Д%') THEN /* уровень сельсовета */ 
          v_ObjectGroup:=c_VillageCouncilValue;	
      ELSIF v_AOLevel = 6 AND UPPER(v_ShortTypeName) NOT IN ('С/С','С/А','С/О','С/МО',
                                                      'САД','СНТ','ТЕР',
                                                      'АВТОДОРОГА',
                                                      'ПРОМЗОНА',
                                                     'ДП','МКР')
               AND UPPER(v_ShortTypeName) NOT LIKE ('Ж/Д%') THEN   /* уровень населенного */
                                                      /* пункта */ 
           v_ObjectGroup:=c_LocalityGroupValue;
       ELSIF  UPPER(v_ShortTypeName) IN ('АВТОДОРОГА') THEN /* уровень */
                                                     /* автомобильной дороги */ 
           v_ObjectGroup:=c_MotorRoadValue;
       ELSIF  v_AOLevel IN (6,7) AND UPPER(v_ShortTypeName) LIKE ('Ж/Д%') THEN 
                                                     /* уровень элемент */
                                                     /* на железной дороге */ 
           v_ObjectGroup:=c_RailWayObjectValue;	
       ELSIF v_AOLevel = 7 AND UPPER(v_ShortTypeName) NOT LIKE ('Ж/Д%') 
                    AND UPPER(v_ShortTypeName) NOT IN ('УЧ-К','ГСК','ПЛ-КА','СНТ','ТЕР') 
                    OR (v_AOLevel in (6, 65) AND UPPER(v_ShortTypeName) IN ('МКР', 'МКР.') )  THEN 
                                                      /* уровень улицы */
          v_ObjectGroup:=c_StreetGroupValue;
      ELSIF v_AOLevel = 90 OR v_AOLevel in (6) AND UPPER(v_ShortTypeName) IN ('САД',
                                                      'СНТ','ТЕР','ПРОМЗОНА','ДП')
                  OR v_AOLevel in (6, 7, 65) THEN
           v_ObjectGroup:=c_AddlTerritoryValue;
      ELSIF v_AOLevel = 91 THEN  /* уровень подчиненных дополнительным территориям */
                                                 /* объектов */ 
           v_ObjectGroup:=c_PartAddlTerritoryValue;
     END IF;	
     RETURN v_ObjectGroup;
  END;
  $BODY$;

ALTER FUNCTION public.fsfn_addressobjects_objectgroup(character varying, integer)
    OWNER TO "gleb.vazhenin";

COMMENT ON FUNCTION public.fsfn_addressobjects_objectgroup(character varying, integer)
    IS 'Возвращает  признак группы адресного объекта по его идентификатору в таблице fias_AddressObjects';
