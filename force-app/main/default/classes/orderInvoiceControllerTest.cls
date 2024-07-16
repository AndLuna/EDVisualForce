/**
 * @description       : 
 * @author            : André Luna
 * @group             : 
 * @last modified on  : 22-06-2024
 * @last modified by  : André Luna
**/
@IsTest
public with sharing class orderInvoiceControllerTest {
    
    @TestSetup
    static void makeData(){
        Map<String, Schema.RecordTypeInfo> OPPORTUNITY_RTS_BY_DEV_NAMES = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName();
        Id visitaMedicaRecordTypeID = OPPORTUNITY_RTS_BY_DEV_NAMES?.get('VisitaFarmacia').recordTypeId;

        Account acc = new Account(
            Name = 'acc teste'
        );
        insert acc;
        
        Profile p = [SELECT Id FROM Profile WHERE Name='Edol Standard User Vendedores' LIMIT 1];
        User seller = new User(
            FirstName = 'Carlos',
            LastName = 'Almeida',
            Email = 'carlos.almeida@example.com',
            Username = 'carlos.almeida@example.com',
            Alias = 'calm',
            TimeZoneSidKey = 'GMT',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = p.Id,
            LanguageLocaleKey = 'en_US'
        );
        insert seller;

        Opportunity opp = new Opportunity(
            Name = 'Test opp',
            StageName = 'Pendente de conclusão',
            RecordTypeId = visitaMedicaRecordTypeID,
            OwnerId = seller.Id
        );
        insert opp;
        
        Order ord = new Order(
            OpportunityId = opp.Id,
            AccountId = acc.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            OrderReferenceNumber__c = 'REF123456'
        );
        insert ord;
    }
    
    @IsTest
    public static void testaComponente2(){
        Test.startTest();

        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        PageReference pageRef = Page.orderInvoice;
        Test.setCurrentPage(pageRef);

        ApexPages.currentPage().getParameters().put('opportunityId', opp.Id);

        orderInvoiceController controller = new orderInvoiceController();
        String formattedOrderReference = controller.getFormattedOrderReference();

        System.assertNotEquals('', formattedOrderReference, 'The formatted order reference should not be empty');
        System.debug('Formatted Order Reference: ' + formattedOrderReference);

        Test.stopTest();
    }

    @IsTest
    public static void testaComponente(){

        Test.startTest();

        Opportunity opp = [SELECT Id 
                            FROM Opportunity
                            LIMIT 1];

        PageReference pageRef = Page.orderInvoice;
        Test.setCurrentPage(pageRef);

        ApexPages.currentPage().getParameters().put('opportunityId', opp.Id);

        orderInvoiceController controller = new orderInvoiceController();

        Test.stopTest();
    }

    @IsTest
    public static void testaExcepcao(){

        Test.startTest();

        orderInvoiceController controller = new orderInvoiceController();
        Test.stopTest();

    }
 @isTest
    static void testGenerateAndSavePDF() {
 		Account acc = [SELECT Id FROM Account LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Order order = [SELECT Id FROM Order LIMIT 1];
        

        Test.startTest();
          orderInvoiceController.getVisualPageAndSavePDF(opp.Id);
        Test.stopTest();

        List<ContentDocumentLink> docLinks = [SELECT ContentDocumentId 
                                                FROM ContentDocumentLink 
                                                WHERE LinkedEntityId = :opp.Id];
        System.assertNotEquals(0, docLinks.size(), 'Expected at least one ContentDocumentLink to be created.');
    }   
 @isTest
    static void testGenerateAndSavePDF2() {

        Account acc = [SELECT Id FROM Account LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Order order = [SELECT Id FROM Order LIMIT 1];

        Test.startTest();
        
        String publicUrl = orderInvoiceController.generateAndSavePDF(opp.Id);
        
        System.assertNotEquals(null, publicUrl, 'A URL pública não deve ser nula');
        System.assertNotEquals('', publicUrl, 'A URL pública não deve ser vazia');
        
        Test.stopTest();

        ContentVersion cv = [SELECT Id, Title, VersionData FROM ContentVersion WHERE FirstPublishLocationId = :opp.Id LIMIT 1];
       // System.assertEquals('PDF Title', cv.Title, 'O título do PDF deve ser "PDF Title"');

        ContentDocumentLink cdl = [SELECT Id, ContentDocumentId, LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId = :opp.Id LIMIT 1];
        System.assertEquals(opp.Id, cdl.LinkedEntityId, 'A ID da entidade vinculada deve corresponder ao ID da conta de teste');
        
        ContentDistribution cd = [SELECT Id, DistributionPublicUrl FROM ContentDistribution WHERE ContentVersionId = :cv.Id LIMIT 1];
        System.assertNotEquals(null, cd.DistributionPublicUrl, 'A URL de distribuição não deve ser nula');
        System.assertNotEquals('', cd.DistributionPublicUrl, 'A URL de distribuição não deve ser vazia');
    }   
    
    @isTest
    static void testDeleteLatestPDF() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Order order = [SELECT Id FROM Order LIMIT 1];

        String publicUrl = orderInvoiceController.generateAndSavePDF(opp.Id);
        System.assertNotEquals(null, publicUrl, 'A URL pública não deve ser nula');
        System.assertNotEquals('', publicUrl, 'A URL pública não deve ser vazia');

        Test.startTest();
         OrderInvoiceController.deleteLatestPDF(opp.Id);
        Test.stopTest();

        List<ContentVersion> versions = [
            SELECT Id 
            FROM ContentVersion 
            WHERE FirstPublishLocationId = :opp.Id 
            AND Title LIKE '%Encomenda%'
        ];
        
        System.assertEquals(0, versions.size(), 'Nenhum ContentVersion deve ser encontrado após a deleção.');
    }
}