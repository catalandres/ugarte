public without sharing class Ugarte {

    final static List<String> HEX = new List<String> {
        '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'
    };

    private static Map<String,List<UgarteRule__mdt>> insertRulesByObjectShadow = null;
    private static Map<String,List<UgarteRule__mdt>> updateRulesByObjectShadow = null;
    private static Boolean isActiveOnInsertShadow = false;
    private static Boolean isActiveOnUpdateShadow = false;

    private static void fetchRules() {
        List<UgarteRule__mdt> allRules = [
            SELECT 
                Object__r.QualifiedAPIName, 
                Field__r.QualifiedAPIName, 
                DoesGenerateOnInsert__c, 
                DoesGenerateOnUpdate__c, 
                UuidType__c
            FROM UgarteRule__mdt
        ];

        insertRulesByObjectShadow = new Map<String,List<UgarteRule__mdt>>();
        updateRulesByObjectShadow = new Map<String,List<UgarteRule__mdt>>();
        isActiveOnInsertShadow = false;
        isActiveOnUpdateShadow = false;

        for (UgarteRule__mdt thisRule: allRules) {
            isActiveOnInsertShadow |= thisRule.DoesGenerateOnInsert__c;
            isActiveOnUpdateShadow |= thisRUle.DoesGenerateOnUpdate__c;
            
            String objectName = thisRule.Object__r.QualifiedAPIName;

            if (!insertRulesByObjectShadow.containsKey(objectName)) {
                insertRulesByObjectShadow.put(
                    objectName,
                    new List<UgarteRule__mdt>()
                );
            }
            if (!updateRulesByObjectShadow.containsKey(objectName)) {
                updateRulesByObjectShadow.put(
                    objectName,
                    new List<UgarteRule__mdt>()
                );
            }

            if (thisRule.DoesGenerateOnInsert__c) {
                insertRulesByObjectShadow.get(objectName).add(thisRule);
            }
            if (thisRule.DoesGenerateOnUpdate__c) {
                updateRulesByObjectShadow.get(objectName).add(thisRule);
            }
        }
    }

    public static Map<String,List<UgarteRule__mdt>> insertRulesByObject {
        get {
            if (insertRulesByObjectShadow == null) {
                fetchRules();
            }
            return insertRulesByObjectShadow;
        }
    }

    public static Map<String,List<UgarteRule__mdt>> updateRulesByObject {
        get {
            if (updateRulesByObjectShadow == null) {
                fetchRules();
            }
            return updateRulesByObjectShadow;
        }
    }

    public static Boolean isActiveOnInsert {
        get {
            if (insertRulesByObjectShadow == null) {
                fetchRules();
            }
            return isActiveOnInsertShadow;
        }
    }

    public static Boolean isActiveOnUpdate {
        get {
            if (updateRulesByObjectShadow == null) {
                fetchRules();
            }
            return isActiveOnInsertShadow;
        }
    }

	public static void handle(
		System.TriggerOperation triggerOperation, 
		List<SObject> records
	) {
        if (records == null || records.isEmpty()) {
            return;
        }
        Map<String,List<UgarteRule__mdt>> applicableRules = new Map<String,List<UgarteRule__mdt>>();
        switch on triggerOperation {
            when BEFORE_INSERT {
                if (!isActiveOnInsert) { return; }
                applicableRules = insertRulesByObject;
            }
            when BEFORE_UPDATE {
                if (!isActiveOnUpdate) { return; }
                applicableRules = updateRulesByObject;
            }
            when else {
                return;
            }
        }
        generate(records, applicableRules);

    }


    public static void generate(List<SObject> records, Map<String,List<UgarteRule__mdt>> applicableRulesByObject) {
        Map<String,List<SObject>> recordsByObject = new Map<String,List<SObject>>();
        for (SObject thisRecord: records) {
            String objectName = thisRecord.getSobjectType().getDescribe().name;
            if (applicableRulesByObject.containsKey(objectName)) {
                if (!recordsByObject.containsKey(objectName)) {
                    recordsByObject.put(objectName, new List<SObject>());
                }
                recordsByObject.get(objectName).add(thisRecord);
            }
        }
        for (String objectName: recordsByObject.keySet()) {
            List<SObject> theseRecords = recordsByObject.get(objectName);
            List<UgarteRule__mdt> theseRules = applicableRulesByObject.get(objectName);
            for (SObject thisRecord: theseRecords) {
                for (UgarteRule__mdt thisRule: theseRules) {
                    String uuid = null;
                    switch on thisRule.UuidType__c {
                        when 'RFC 4112 v4' {
                            Uuid = generateRfc4112V4();
                        }
                        when 'Salesforce Record ID' {
                            Uuid = thisRecord.Id;
                        }
                    }
                    thisRecord.put(thisRule.Field__r.QualifiedAPIName, uuid);
                }
            }
        }
    }

    private static Integer convertHexToInt(String hexadecimalValue) {
        // Source: https://salesforce.stackexchange.com/a/223381
        Integer digit0 = HEX.indexOf(hexadecimalValue.substring(1,2));
        Integer digit1 = HEX.indexOf(hexadecimalValue.substring(0,1));

        Integer integerValue = digit0 + (digit1 * 16);
        return integerValue;
    }

    private static String convertIntToHex(Integer integerValue) {
        // Source: https://salesforce.stackexchange.com/a/223381
        String hs0 = HEX.get(integerValue & 15); // i & 0x0f
        String hs1 = HEX.get(((integerValue >> 4) & 15)); //(i >> 4) & 0x0f        
        return hs1+hs0;
    }

    public static String generateRfc4112V4() {
        // Source: https://salesforce.stackexchange.com/a/223381
        String randomStringAsHex = EncodingUtil.convertTohex(Crypto.generateAesKey(128));

        Integer versionIntBits = convertHexToInt(randomStringAsHex.substring(14,16)); // 7th bit 
        Integer variantIntBits = convertHexToInt(randomStringAsHex.substring(18,20)); // 9th bit

        Integer versionShiftedIntBits = versionIntBits & 15 | 64;  // (i & 0x0f) | 0x40
        Integer variantShiftedIntBits = variantIntBits & 63 | 128; // (i & 0x3f) | 0x80

        String versionShiftedHexBits = convertIntToHex(versionShiftedIntBits); // Always begins with 4
        String variantShiftedHexBits = convertIntToHex(variantShiftedIntBits); // Always begins with one of 8,9,a,b

        return 
            randomStringAsHex.SubString(0,8) 
            + '-' 
            + randomStringAsHex.SubString(8,12) 
            + '-' 
            + versionShiftedHexBits 
            + randomStringAsHex.SubString(14,16) 
            + '-' 
            + variantShiftedHexBits 
            + randomStringAsHex.SubString(18,20) 
            + '-' 
            + randomStringAsHex.substring(20);
    }
}
