@isTest(isParallel=true)
private without sharing class UgarteTest {

    private static final Integer TEST_SIZE = 200;

    @isTest
    private static void onProductInsert() {
        List<Product2> products = new List<Product2>();

        for (Integer i=0; i<TEST_SIZE; i++) {
            products.add(
                new Product2(
                    Name = 'Something'
                )
            );
        }

        Test.startTest();
        insert products;
        Test.stopTest();

        products = [
            SELECT Id, Uuid__c
            FROM Product2
            WHERE Id IN :products
        ];

        for (Product2 thisProduct: products) {
            System.assert(thisProduct.Uuid__c != null, 'The UUID field is unexpectedly null.');
        }

        

    }

}
