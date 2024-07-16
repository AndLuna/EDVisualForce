/**
 * @description       : 
 * @author            : André Luna
 * @group             : 
 * @last modified on  : 22-06-2024
 * @last modified by  : André Luna
**/
public without sharing class orderInvoiceController {
    private static final String CLASS_NAME = 'orderInvoiceController';

    public String paramId                              { get; set; }
    public Opportunity opportunity                     { get; set; }
    public Account account                             { get; set; }
    public Order order                                 { get; set; }
    public String data                                 { get; set; }
    public List<OrderItem> orderItems                  { get; set; }
    public Id opportunityId                            { get; set; }
    public List<Order> childOrders                     { get; set; }
    public Map<Id, List<OrderItem>> childOrderItemsMap { get; set; }
    public List<OrderItem> combinedOrderItems          { get; set; }
    public Decimal totalAmountWithDiscountSum          { get; set; }
    public Integer totalItemsSum                       { get; set; }
    public String formattedOrderCreationDate           { get; set; }

    private String mesesStr              = ',Janeiro,Fevereiro,Março,Abril,Meio,Junho,Julho,Agosto,Setembro,Outubro,Novembro,Dezembro';
    public List<String> meses            = mesesStr.split(',');

    public orderInvoiceController() {
        List<Order> orderList            = new List<Order>();
        List<Account> accountList        = new List<Account>();
        orderItems                       = new List<OrderItem>();
        combinedOrderItems               = new List<OrderItem>();
        childOrderItemsMap               = new Map<Id, List<OrderItem>>();
        totalAmountWithDiscountSum       = 0;
        totalItemsSum                    = 0;

        try {
            paramId = ApexPages.currentPage().getParameters().get('opportunityId');
            data = date.today().day() + ' de ' + meses[date.today().month()] + ' de ' + date.today().year();

            if (String.isNotBlank(paramId)) {
                opportunity = [SELECT
                Id, 
                AccountId, 
                Name, 
                Owner.FirstName, 
                Owner.LastName, 
                Owner.Name
                               FROM Opportunity
                               WHERE Id = :paramId
                               LIMIT 1];

                accountList = [SELECT 
                Id, 
                Name, 
                Phone, 
                Nclient__c, 
                TaxpayerNumber__c, 
                PaymentTermsCode__c,
                BillingPostalCode__c,
                BillingPostalCode,
                BillingStreet
                               FROM Account
                               WHERE Id= :opportunity.AccountId
                               LIMIT 1];

                if(!accountList.isEmpty()){ 
                    account = accountList[0]; 
                }
            }

            orderList = [SELECT 
                   Id, 
                   OpportunityId,
                   Account.Name,
                   OrderNumberERP__c,
                   OrderNumber, 
                   ShippingStreet__c,
                   ShippingPostalCode__c,
                   TotalAmount, OrderReferenceNumber__c, 
                   TotalAmountDiscount__c,
                   TotalAmountWithDiscount__c,
                   effectiveDate,
                   ShipToClient__r.Name, 
                   SUM_Total_Itens__c,
                   CreatedDate
                FROM Order 
                WHERE OpportunityId = :opportunity.Id 
                ORDER BY Id DESC 
                LIMIT 1
            ];

            if (!orderList.isEmpty()) { 
                order = orderList[0];
                totalAmountWithDiscountSum += (order.TotalAmountWithDiscount__c != null) ? order.TotalAmountWithDiscount__c : 0;
                totalItemsSum += (order.SUM_Total_Itens__c != null) ? Integer.valueOf(order.SUM_Total_Itens__c) : 0;

                // Formatar a data de criação da ordem
                formattedOrderCreationDate = order.CreatedDate.format('dd-MM-yyyy');
            }

            orderItems = [SELECT 
            Id, 
            OrderID, 
            product2.Name, 
            product2.ProdutoType__c, 
            Quantity, 
            UnitPrice, 
            NetPrice__c, 
            TotalPrice, 
            DiscountAmountLine__c, 
            DiscountPercentage__c, 
            TotalNetPrice__c, 
            Product2.ProductN__c,
            Product2.Description2__c
                          FROM OrderItem
                          WHERE OrderID = :order.Id];
            System.debug('orderItems:: ' + orderItems);

            combinedOrderItems.addAll(orderItems);

            childOrders = [SELECT 
            Id, 
            Account.Name,
            TotalAmountWithDiscount__c, 
            SUM_Total_Itens__c 
            FROM 
            Order 
            WHERE OrderId__c = :order.Id
            ORDER BY Account.Name ASC ];

            if (!childOrders.isEmpty()) {
                List<Id> childOrderIds = new List<Id>();
                for (Order childOrder : childOrders) {
                    childOrderIds.add(childOrder.Id);
                    totalAmountWithDiscountSum += (childOrder.TotalAmountWithDiscount__c != null) ? childOrder.TotalAmountWithDiscount__c : 0;
                    totalItemsSum += (childOrder.SUM_Total_Itens__c != null) ? Integer.valueOf(childOrder.SUM_Total_Itens__c) : 0;
                }

                List<OrderItem> childOrderItems = [SELECT 
                Id, 
                OrderID,
                Order.Account.Name, 
                product2.Name, 
                product2.ProdutoType__c, 
                Quantity, 
                UnitPrice, 
                NetPrice__c, 
                TotalNetPrice__c,
                TotalPrice, 
                DiscountAmountLine__c,
                DiscountPercentage__c, 
                Product2.ProductN__c,
                Product2.Description2__c  
                                                   FROM OrderItem 
                                                   WHERE OrderID IN :childOrderIds];

                // Preencher o mapa childOrderItemsMap
                for (OrderItem childItem : childOrderItems) {
                    if (!childOrderItemsMap.containsKey(childItem.OrderId)) {
                        childOrderItemsMap.put(childItem.OrderId, new List<OrderItem>());
                    }
                    childOrderItemsMap.get(childItem.OrderId).add(childItem);
                }

                combinedOrderItems.addAll(childOrderItems);
            }
        } catch (Exception ex) {
            System.debug(CLASS_NAME + '::ERROR::');
            System.debug(CLASS_NAME + ' the following exception has occured:' + ex.getMessage());
            System.debug(CLASS_NAME + ' the following Line:' + ex.getLineNumber());
        }
    }

    @Future(callout=true)
    public static void getVisualPageAndSavePDF(Id recordId) {
        system.debug('recordId' + recordId);
    
        Order orderInfo = [SELECT ID, OrderNumber, CreatedDate FROM Order WHERE OpportunityId = :recordId Order by createdDate Desc Limit 1];
        system.debug('orderInfo' + orderInfo);
    
        String formattedDate = orderInfo.CreatedDate.format('yyyy-MM-dd', 'GMT');
        PageReference pageRef = new PageReference('/apex/OrderInvoice');
        pageRef.getParameters().put('opportunityId', recordId);
        Blob pdfBlob;
        if (Test.isRunningTest()) {
            pdfBlob = Blob.valueOf('Unit.Test');
        } else {
            pdfBlob = pageRef.getContentAsPDF();
        }
    
        Integer versionCount = [SELECT COUNT() FROM ContentVersion WHERE FirstPublishLocationId = :recordId];
    
        ContentVersion cv = new ContentVersion();
        cv.Title = 'Encomenda ' + orderInfo.OrderNumber + ' - ' + formattedDate + ' - V' + (versionCount + 1);
        cv.PathOnClient = 'file.pdf';
        cv.VersionData = pdfBlob;
        cv.FirstPublishLocationId = recordId;
        insert cv;
    
        Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
    
        List<ContentDocumentLink> existingLinks = [
            SELECT Id FROM ContentDocumentLink 
            WHERE ContentDocumentId = :contentDocumentId AND LinkedEntityId = :recordId
        ];
        if (existingLinks.isEmpty()) {
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = contentDocumentId;
            cdl.LinkedEntityId = recordId;
            cdl.ShareType = 'V';
            cdl.Visibility = 'AllUsers';
            insert cdl;
        }
    
        ContentDistribution contentDistribution = new ContentDistribution();
        contentDistribution.Name = 'Public Link for ' + cv.Title;
        contentDistribution.ContentVersionId = cv.Id;
        insert contentDistribution;
    }

    public Boolean isDiscountPercentageNotNull(OrderItem item) {
        return item.DiscountPercentage__c != null;
    }

    public String getFormattedOrderReference() {
        String sellerInitials = '';
        if (opportunity.Owner.FirstName != null && opportunity.Owner.LastName != null) {
            sellerInitials = opportunity.Owner.FirstName.substring(0, 1) + opportunity.Owner.LastName.substring(0, 1);
        }

        Datetime today = Datetime.now();    
        String formattedDate = today.format('yyDDD');
        String formattedOrderReference = sellerInitials + formattedDate + '/' + order.OrderNumber;
        return formattedOrderReference;
    }

    @AuraEnabled
    public static String generateAndSavePDF(Id recordId) {

        Order   orderInfo     = [SELECT ID, OrderNumber, CreatedDate FROM Order WHERE OpportunityId = :recordId Order by createdDate Desc Limit 1];
        String  formattedDate = orderInfo.CreatedDate.format('yyyy-MM-dd', 'GMT');
        Integer versionCount  = [SELECT COUNT() FROM ContentVersion WHERE FirstPublishLocationId = :recordId];

        PageReference pageRef = new PageReference('/apex/OrderInvoice');
        pageRef.getParameters().put('opportunityId', recordId);
        Blob pdfBlob;
        if (Test.isRunningTest()) {
            pdfBlob = Blob.valueOf('Unit.Test');
        } else {
            pdfBlob = pageRef.getContentAsPDF();
        }

        ContentVersion cv = new ContentVersion();
        cv.Title = 'Encomenda ' + orderInfo.OrderNumber + ' - ' + formattedDate + ' - V' + (versionCount + 1);
        cv.PathOnClient = 'file.pdf';
        cv.VersionData = pdfBlob;
        cv.FirstPublishLocationId = recordId;
        insert cv;

        // Obtém o ID do ContentDocument associado ao ContentVersion
        Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        List<ContentDocumentLink> existingLinks = [
            SELECT Id FROM ContentDocumentLink 
            WHERE ContentDocumentId = :contentDocumentId AND LinkedEntityId = :recordId
        ];
        if (existingLinks.isEmpty()) {
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = contentDocumentId;
            cdl.LinkedEntityId = recordId;
            cdl.ShareType = 'V';
            cdl.Visibility = 'AllUsers';
            insert cdl;
        }

        ContentDistribution contentDistribution = new ContentDistribution();
        contentDistribution.Name = 'Public Link for ' + cv.Title;
        contentDistribution.ContentVersionId = cv.Id;
        insert contentDistribution;

        contentDistribution = [
            SELECT DistributionPublicUrl
            FROM ContentDistribution
            WHERE Id = :contentDistribution.Id
        ];

        String publicUrl = contentDistribution.DistributionPublicUrl;

        if (!Test.isRunningTest()) {
            String jobId = System.schedule('Delete PDF ' + cv.Id, '0 0 0 * * ?', new ScheduledDeletePDF(contentDocumentId));
        }

        return publicUrl;
    }

    @AuraEnabled
    public static void deleteLatestPDF(Id recordId) {
        try {
            // Find the latest ContentVersion for the given recordId
            ContentVersion latestVersion = [
                SELECT Id, ContentDocumentId 
                FROM ContentVersion 
                WHERE FirstPublishLocationId = :recordId 
                AND Title Like '%Encomenda%'
                ORDER BY CreatedDate DESC 
                LIMIT 1
            ];

            // Delete the ContentDocument associated with this ContentVersion
            if (latestVersion != null) {
                ContentDocument document = [
                    SELECT Id 
                    FROM ContentDocument 
                    WHERE Id = :latestVersion.ContentDocumentId 
                    LIMIT 1
                ];
                delete document;
                System.debug('ContentDocument deleted successfully');
            }
        } catch (Exception e) {
            System.debug('Error deleting PDF: ' + e.getMessage());
            throw new AuraHandledException('Error deleting PDF: ' + e.getMessage());
        }
    }
}