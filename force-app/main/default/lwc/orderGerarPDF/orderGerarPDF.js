/**
 * @description       : 
 * @author            : André Luna
 * @group             : 
 * @last modified on  : 22-06-2024
 * @last modified by  : André Luna
**/
import { LightningElement, api, track } from 'lwc';
import generateAndSavePDF from '@salesforce/apex/orderInvoiceController.generateAndSavePDF';
import deleteLatestPDF from '@salesforce/apex/orderInvoiceController.deleteLatestPDF';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class OrderGerarPDF extends LightningElement {
    @api recordId;
    @track pdfUrl;

    connectedCallback() {
        this.loadPDF();
    }

    loadPDF() {
        generateAndSavePDF({ recordId: this.recordId })
            .then(result => {
                this.pdfUrl = result;
            })
            .catch(error => {
                console.error('Error generating PDF: ', error);
            });
    }

    handleCancel() {
        deleteLatestPDF({ recordId: this.recordId })
            .then(() => {
                console.log('PDF deleted successfully');
                this.closeQuickAction(); // Call to close the modal
            })
            .catch(error => {
                console.error('Error deleting PDF: ', error);
            });
    }

    handleSave() {
        // Show success toast
        const toastEvent = new ShowToastEvent({
            title: 'Sucesso',
            message: 'PDF salvo com sucesso!',
            variant: 'success',
        });
        this.dispatchEvent(toastEvent);

        this.closeQuickAction(); // Close the modal
    }

    closeQuickAction() {
        const closeEvent = new CustomEvent('close');
        this.dispatchEvent(closeEvent);
    }
}