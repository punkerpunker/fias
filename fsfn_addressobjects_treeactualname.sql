-- FUNCTION: public.fsfn_addressobjects_treeactualname(character varying, character varying[])

-- DROP FUNCTION public.fsfn_addressobjects_treeactualname(character varying, character varying[]);

CREATE OR REPLACE FUNCTION public.fsfn_addressobjects_treeactualname(
	a_aoguid character varying DEFAULT NULL::character varying,
	a_maskarray character varying[] DEFAULT '{TP,LM,LP,ST}'::character varying[])
    RETURNS character varying
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE 
AS $BODY$
DECLARE
	c_CountryGroupValue	 CONSTANT VARCHAR(50):='Country'; /* Признак группы - Страна*/	
	c_RegionGroupValue	 CONSTANT VARCHAR(50):='Region'; /* Признак группы - Регион*/	
	c_CityGroupValue	 CONSTANT VARCHAR(50):='City';	/* Признак группы - Основной */
                                                                /* населенный пункт*/	
	c_TerritoryGroupValue CONSTANT VARCHAR(50):='Territory';/* Признак группы - район */	
	c_LocalityGroupValue   CONSTANT VARCHAR(50):='Locality';/* Признак группы - */
                                                                /* населенный  пункт, */
                                                                /* подчиненный основному */	
	c_MotorRoadValue      CONSTANT VARCHAR(50):='MotorRoad';/* Признак группы - */
                                                                /* автомобильная дорога */	
	c_RailWayObjectValue	 CONSTANT VARCHAR(50):='RailWayObject';/* Признак группы - */
                                                                /* железная дорога */	
	c_VillageCouncilValue	 CONSTANT VARCHAR(50):='VillageCouncil';
                                                                /* Признак группы - сельсовет */
	c_StreetGroupValue	  CONSTANT VARCHAR(50):='Street';
                                                                 /* Признак группы - */
                                                                /* улица в населенном пункте */	
	c_AddlTerritoryValue	 CONSTANT VARCHAR(50):='AddlTerritory';/* Признак группы - */
                                                                /* дополнительная территория*/	
	c_PartAddlTerritoryValue CONSTANT VARCHAR(50):='PartAddlTerritory';/* Признак группы */
                                                      /* - часть дополнительной территории*/	
	c_StreetMask	 	CONSTANT  VARCHAR(2)[1] :='{ST}';/* Маска улица */
	c_PostIndexMask	CONSTANT  VARCHAR(2)[1] :='{ZC}';/* Маска почтовый индекс */
	c_DistrictMask		CONSTANT  VARCHAR(2)[1] :='{DT}';/* Маска городской район*/
	c_PartLocalityMask	CONSTANT  VARCHAR(2)[1] :='{LP}';/* Маска подчиненный */
                                                                /* населенный пункт*/
	c_PartLocality2Mask	CONSTANT  VARCHAR(3)[1] :='{LP2}';/* Маска подчиненный */
                                                                /* населенный пункт*/														
	c_MainLocalityMask	CONSTANT  VARCHAR(2)[1] :='{LM}';/* Маска основной */
                                                                /* населенный пункт*/
	c_PartTerritoryMask	CONSTANT  VARCHAR(2)[1] :='{TP}';/* Маска района */
                                                                /* субъекта федерации*/
	c_MainTerritoryMask	CONSTANT  VARCHAR(2)[1] :='{TM}';/* Маска субъект федерации */
                                                                /* (регион)*/
	c_CountryMask		CONSTANT  VARCHAR(2)[1] :='{CY}';/* Маска страна*/
	v_ShortTypeName	VARCHAR(10);	/* Тип адресообразующего элемента */ 
	v_AddressObjectName VARCHAR(100); /* Название адресообразующего элемента */
	v_AOLevel                INTEGER;         /* Уровень адресообразующего элемента*/	
	v_MinCurrStatus       INTEGER;		/* Минимальное значение текущего статуса */
                                                                 /* адресообразующего элемента*/	
	v_TreeAddressObjectName	VARCHAR(1000); /* Полное в иерархии название элемента*/ 
	v_ObjectGroup         VARCHAR(50); /* Группа адресообразующего элемента */
	v_TreeLeverCount    INTEGER;		/* Счетчик цикла*/
	v_Return_Error_i     Integer := 0;     /* Код возврата*/
	cursor_AddressObjectTree RefCURSOR;  /* курсор по иерархии адреса*/
	v_Return_Error       Integer :=0;	/* Код возврата */
--******************************************************************************  
--******************************************************************************
 BEGIN
	SELECT INTO v_MinCurrStatus MIN(addrobj.currstatus) 
          FROM addrob addrobj
          WHERE aoguid=a_AOGUID;
	OPEN cursor_AddressObjectTree FOR SELECT rtf_ShortTypeName,
                        REPLACE(rtf_AddressObjectName,'  ',' '),
                       rtf_AOLevel,fsfn_AddressObjects_ObjectGroup(rtf_AOGUID )
          FROM fstf_AddressObjects_AddressObjectTree(a_AOGUID) 
          ORDER BY rtf_AOLevel;
	v_TreeLeverCount:=0;
	v_TreeAddressObjectName:='';
	FETCH FIRST FROM cursor_AddressObjectTree INTO v_ShortTypeName,v_AddressObjectName,
                        v_AOLevel,v_ObjectGroup;
	WHILE FOUND
	LOOP
		v_TreeLeverCount:=v_TreeLeverCount+1;	
		IF v_ObjectGroup=c_CountryGroupValue AND c_CountryMask <@ a_MaskArray 
                                     AND v_AOLevel =0 THEN
			v_TreeAddressObjectName:=v_TreeAddressObjectName||
                               CASE WHEN v_TreeAddressObjectName='' THEN ''  
                                  ELSE ', ' END ||
                               v_AddressObjectName||' '||v_ShortTypeName;
		ELSIF v_ObjectGroup=c_RegionGroupValue 
                                     AND c_MainTerritoryMask <@ a_MaskArray
                                     AND v_AOLevel <=2 THEN
			v_TreeAddressObjectName:=v_TreeAddressObjectName||
                                CASE WHEN v_TreeAddressObjectName='' THEN ''
                                         ELSE ', ' END ||
                                CASE WHEN UPPER(v_ShortTypeName) LIKE 
                                               UPPER('%Респ%') THEN 'Республика ' ||
                               v_AddressObjectName ELSE v_AddressObjectName||
                                              ' '||v_ShortTypeName END;
		ELSIF v_ObjectGroup=c_TerritoryGroupValue 
                                     AND c_PartTerritoryMask <@ a_MaskArray 
                                     AND v_AOLevel =3 THEN
			v_TreeAddressObjectName:=v_TreeAddressObjectName||
                                CASE WHEN v_TreeAddressObjectName='' THEN ''
                                         ELSE ', ' END ||
                                v_AddressObjectName||' '||v_ShortTypeName;
		ELSIF v_ObjectGroup=c_CityGroupValue
                                     AND c_MainLocalityMask <@ a_MaskArray AND v_AOLevel =4 THEN
			v_TreeAddressObjectName:=v_TreeAddressObjectName||
                                    CASE WHEN v_TreeAddressObjectName='' THEN ''
                                          ELSE ', ' END ||
                                     CASE WHEN UPPER(LEFT(v_AddressObjectName,6+
                                         LENGTH(v_ShortTypeName)))='ЗАТО '||
                                         UPPER(TRIM(v_ShortTypeName))||'.'  THEN
                                             v_AddressObjectName
                                       ELSE v_ShortTypeName ||' '|| v_AddressObjectName END;
		ELSIF v_ObjectGroup=c_LocalityGroupValue 
                                     AND c_DistrictMask <@ a_MaskArray AND v_AOLevel =5 THEN
			v_TreeAddressObjectName:=v_TreeAddressObjectName||
                                    CASE WHEN v_TreeAddressObjectName='' THEN '' 
                                        ELSE ', ' END ||
                                    v_AddressObjectName||' '||v_ShortTypeName ;
		ELSIF v_ObjectGroup=c_LocalityGroupValue 
                                    AND c_PartLocalityMask <@ a_MaskArray 
                                    AND v_AOLevel = 6 THEN
			v_TreeAddressObjectName:=v_TreeAddressObjectName||
                                   CASE WHEN v_TreeAddressObjectName='' THEN ''
                                        ELSE ', ' END ||
                                   v_ShortTypeName ||' '|| v_AddressObjectName;
		ELSIF v_ObjectGroup=c_StreetGroupValue 
                                   AND c_StreetMask <@ a_MaskArray 
                                   AND v_AOLevel in (7, 65)   THEN
			v_TreeAddressObjectName:=v_TreeAddressObjectName||
                                   CASE WHEN v_TreeAddressObjectName='' THEN '' 
                                        ELSE ', ' END ||
                                   v_ShortTypeName ||' '|| v_AddressObjectName;
		ELSIF v_ObjectGroup=c_AddlTerritoryValue
                                    AND c_PartLocality2Mask <@ a_MaskArray 
                                    AND v_AOLevel in (6, 7, 65) THEN
			v_TreeAddressObjectName:=v_TreeAddressObjectName||
                                   CASE WHEN v_TreeAddressObjectName='' THEN ''
                                        ELSE ', ' END ||
                                   v_ShortTypeName ||' '|| v_AddressObjectName;
		END IF;
		FETCH NEXT  FROM cursor_AddressObjectTree INTO v_ShortTypeName,
                                                                                            v_AddressObjectName,
                                                                                            v_AOLevel,v_ObjectGroup;
	END LOOP;
	CLOSE cursor_AddressObjectTree;
 	RETURN 	v_TreeAddressObjectName;
  END;
  $BODY$;

ALTER FUNCTION public.fsfn_addressobjects_treeactualname(character varying, character varying[])
    OWNER TO "gleb.vazhenin";

COMMENT ON FUNCTION public.fsfn_addressobjects_treeactualname(character varying, character varying[])
    IS 'Возвращает  строку с полным названием адресообразующего элемента';
