Ext.namespace('Ung');
// The location of the blank pixel image
Ext.define('Ung.Wizard', {
    extend:'Ext.container.Container',
    border: 1,
    layout: { type: 'hbox', align: 'stretch' },
    currentPage: 0,
    hasCancel: false,
    modalFinish: false, //can not go back or cancel on finish step
    finished: false,
    initComponent : function() {
        var logo_container = Ext.get('extra-div-1');
        logo_container.addCls( 'logo-container');
        var logo = document.createElement('img');
        logo.src= '../images/BrandingLogo.png';
        logo_container.appendChild(logo);
        // Build a panel to hold the headers on the left
        this.headerPanel = Ext.create('Ext.container.Container', {
            cls: 'wizard-steps',
            layout: { type: 'vbox', align: 'right'},
            flex: 0,
            width: 200,
            defaults: { border : false, width : 200 },
            items: this.buildHeaders( this.cards )
        } );

        var panels = [];

        var length = this.cards.length;
        for ( c = 0 ;c < length ; c++ ) panels.push(this.cards[c].panel );
        if(this.hasCancel) {
            this.cancelButton = Ext.create('Ext.button.Button',{
                id : 'cancel',
                iconCls: 'cancel-icon',
                text : i18n._( 'Cancel' ),
                handler : Ext.bind(function() {
                    this.cancelAction();
                },this)
            });
        }
        this.previousButton = Ext.create('Ext.button.Button', {
            id : 'card-prev',
            text : Ext.String.format(i18n._( '{0} Previous' ),'&laquo;'),
            handler : Ext.bind(this.goPrevious, this ),
            cls:'x-btn-always-over small-right-margin'
        });

        this.nextButton = Ext.create('Ext.button.Button',{
            id : 'card-next',
            text : Ext.String.format(i18n._( 'Next {0}' ),'&raquo;'),
            handler : Ext.bind(this.goNext, this ),
            cls:'x-btn-always-over'
        });

        if ( this.cardDefaults == null ) this.cardDefaults = {};
        Ext.apply(this.cardDefaults, {
            border: true,
            autoScroll: true
        });
        var bbarArr=[ '->', this.previousButton, this.nextButton , { xtype: 'tbspacer', width: 15 }];
        if(this.hasCancel) {
            bbarArr.unshift(this.cancelButton);
        };
        // Build a card to hold the wizard
        this.contentPanel = Ext.create('Ext.panel.Panel',{
            layout : "card",
            flex: 1,
            items : panels,
            activeItem : 0,
            defaults : this.cardDefaults,
            bbar : bbarArr,
            border:false
        });
        this.items = [ this.headerPanel, this.contentPanel ];
        this.callParent(arguments);
    },
    buildHeaders : function( cards ) {
        var items = [];
        var length = cards.length;
        for ( var c = 0 ; c < length ; c++ ) {
            var card = cards[c];
            var addnlclass = '';
            if(c === 0 || c == length -1){
                addnlclass = ' nostep ';
            }
            var title = '<span class="text'+addnlclass+'">' + card.title + '</span>';
            if (( c > 0 ) && ( c < ( length - 1 ))) {
                title = Ext.String.format( '<span class="count">{0}</span> ', c  ) + title;
            }
            var id = this.getStepId( c );
            items.push({
                xtype: 'component',
                html : title,
                cls : 'step'
            });
        }
        return items;
    },
    getStepId : function( index ) {
        return "wizard-step-" + index;
    },
    goPrevious : function() {
        this.goToPage( this.currentPage - 1 );
    },
    goNext : function() {
        this.goToPage( this.currentPage + 1 );
    },
    goToPage : function( index ) {
        if ( index >= this.cards.length ) index = this.cards.length - 1;
        if ( index < 0 ) index = 0;

        var hasChanged = false;
        var handler = null;
        var validationPassed = true;
        if(validationPassed === true){
            if ( this.currentPage <= index ) {
                if(this.cards[this.currentPage].onValidate){
                    validationPassed = this.cards[this.currentPage].onValidate();
                }
                if(validationPassed === true){
                    /* moving forward, call the forward handler */
                    hasChanged = true;
                    handler = this.cards[this.currentPage].onNext;
                }else{
                    return false;
                }
            } else if ( this.currentPage > index ) {
                hasChanged = true;
                handler = this.cards[this.currentPage].onPrevious;
            }
        } else {
            return false;
        }

        if ( this.disableNext == true ) handler = null;
        /* If the page has changed and it is defined, then call the handler */
        if ( handler ) {
            handler( Ext.bind(this.afterChangeHandler, this, [ index, hasChanged ] ));
        } else {
            //where are we going if there is no handler? - karthik
            this.afterChangeHandler( index, hasChanged );
        }
        return true;
    },

    cancelAction: function () {
    },
    /* This function must be called once the the onPrevious or onNext handler completes,
     * broken into its own function so the handler can run asynchronously */
    afterChangeHandler : function( index, hasChanged ) {
        this.currentPage = index;
        var card = this.cards[this.currentPage];
        handler = card.onLoad;
        if ( hasChanged && ( handler )) {
            handler( Ext.bind(this.afterLoadHandler, this ));
        } else {
            this.afterLoadHandler();
        }
    },

    afterLoadHandler : function() {
        this.contentPanel.getLayout().setActiveItem( this.currentPage );
        /* You have to force the layout for components that need to recalculate their heights */
        //this.contentPanel.updateLayout();
        /* retrieve all of the items */
        var items = this.headerPanel.query('component');
        var length = items.length;
        var isComplete = true;
        for ( var c = 0 ; c < length ; c++ ) {
            var item = items[c];
            if ( c == this.currentPage ) {
                item.removeCls( "incomplete" );
                item.removeCls( "completed" );
                item.addCls( "current" );
                isComplete = false;
            } else {
                item.removeCls( "current" );
                if ( isComplete ) {
                    item.removeCls( "incomplete" );
                    item.addCls( "completed" );
                } else {
                    item.removeCls( "completed" );
                    item.addCls( "incomplete" );
                }
            }
        }

        if ( this.currentPage == 0 || (this.modalFinish && this.currentPage == ( length - 1 ))) {
            this.previousButton.hide();
        } else {
            this.previousButton.show();
        }

        if ( this.currentPage == ( length - 1 )) {
            if(this.modalFinish) {
                this.nextButton.setText( i18n._('Close') );
                if(this.hasCancel) {
                   this.cancelButton.hide();
                }
                this.finished=true;
            } else {
                this.nextButton.setText( i18n._('Finish') );
            }
        } else {
            this.nextButton.setText( Ext.String.format(i18n._('Next {0}'),"&raquo;"));
            if(this.hasCancel) {
                this.cancelButton.show();
            }
        }
    },

    getCardTitle : function( index, card ){
        var title = card.cardTitle;
        if ( title == null ) title = card.title;

        if (( index > 0 ) && ( index < ( this.cards.length - 1 ))) {
            if ( title == null ) title = Ext.String.format( i18n._('Step {0}'), index );
            else title = Ext.String.format( i18n._('Step {0}'), index + ' - ' + title) ;
        }
        return title;
    }
});