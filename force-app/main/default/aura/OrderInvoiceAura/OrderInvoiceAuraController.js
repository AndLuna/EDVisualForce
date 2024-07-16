/**
 * @description       : 
 * @author            : André Galvinas
 * @group             : 
 * @last modified on  : 04-07-2024
 * @last modified by  : André Luna
 * Modifications Log
 * Ver   Date         Author           Modification
 * 1.0   03-07-2024   André Luna   Initial Version
**/
({
    init: function(component, event, helper) {
        console.log('Component initialized');
    },
    
    closeModal: function(component, event, helper) {
        $A.get("e.force:closeQuickAction").fire(); 
        $A.get("e.force:refreshView").fire(); 
    }
})