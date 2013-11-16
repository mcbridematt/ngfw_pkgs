Ext.ns('Ung');
Ext.ns('Ung.Alpaca');

/**
 * @class Ung.Alpaca.PagePanel
 * @extends Ext.Panel
 * A PagePanel is the base for rendering a page on the alpaca.
 * 
 */
Ung.Alpaca.PagePanel = Ext.extend( Ext.Panel, {
    border : false,

    layout : "form",

    autoScroll : true,
    cls:'alpaca-panel',

    constructor : function( config ) {
        //this.settings = config.settings;
        this.i18n = new Ung.ModuleI18N({ "map" : Ung.Alpaca.i18n,
                                         "moduleMap" : config.i18nMap});
        this._ = this.i18n._.createDelegate( this.i18n );
        
        Ung.Alpaca.PagePanel.superclass.constructor.apply( this, arguments );
    },
    
    // Populate the fields with the 
    // values from the settings objects.  This uses the name
    // to automatically determine which values belong in the fields.
    populateForm : function()
    {
        /* Iterate the panel and line up fields with their values. */
        this.items.each( this.populateFieldValue.createDelegate( this, [ this.settings ], true ));

        /* Register the event handler with every field. */
        this.items.each( this.addEnableSaveHandler.createDelegate( this ));
    },
    
    /* Fill in the value for a field */
    populateFieldValue : function( item, index, length, settings )
    {
        if ( item.getName ) {
            var value = Ung.Alpaca.Util.getSettingsValue( settings, item.getName());

            if ( value == null ) {
                value = item.defaultValue;
            }

            switch ( item.xtype ) {
            case "numberfield":
            case "textfield":
            case "textarea":
                value = ( value == null ) ? "" : value;
                item.setValue( value );
                break;
                
            case "checkbox":
                value =  ( value == null ) ? false : value;
                var invert = item.invert;
                if ( invert == true ) value = !value;
                item.setValue( value );
                break;

            case "combo":
                if ( value != null ) {
                    item.setValue( value );
                }
                break;                
            }
        }

        /* Recurse to children */
        if ( item.items ) {
            item.items.each( this.populateFieldValue.createDelegate( this, [ settings ], true ));
        }
    },
    
    addEnableSaveHandler : function( item, index )
    {
        if ( item.addListener && item.xtype ) {
            var event = "change";
            
            switch ( item.xtype ) {
            case "checkbox":
                event = "check"
                break;

                /* No point registering events on labels. */
            case "label":
                event = null;
            default:
            }

            if ( item.editorGridPanel == true ) {
                event = "afteredit"
            }
            
            if ( event != null ) {
                item.addListener( event, application.onFieldChange, application );
            }
        }

        if ( item.items ) {
            item.items.each( this.addEnableSaveHandler.createDelegate( this ));
        }
    },

    updateSettings : function( settings )
    {
        /* Iterate the panel and line up fields with their values. */
        this.items.each( this.updateFieldValue.createDelegate( this, [ settings ], true ));
    },
    
    /* Update the settings with the values from the fields. */
    updateFieldValue : function( item, index, length, settings )
    {
        if ( item.updateFieldValue ) {
            item.updateFieldValue( settings );
        } else if ( item.getName ) {
            var value = null;

            switch ( item.xtype ) {
            case "textfield":
            case "textarea":
            case "numberfield":
            case "combo":
                value = item.getValue();
                break;

            case "checkbox":
                value = item.getValue();
                if ( item.invert ) {
                    value = !value;
                }
            }
            
            if ( value != null ) {
                Ung.Alpaca.Util.setSettingsValue( settings, item.getName(), value );
            }
        }

        /* Recurse to children */
        if ( item.items ) {
            item.items.each( this.updateFieldValue.createDelegate( this, [ settings ], true ));
        }
    }
});