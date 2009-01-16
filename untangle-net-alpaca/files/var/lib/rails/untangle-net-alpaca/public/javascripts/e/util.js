Ext.ns('Ung');
Ext.ns('Ung.Alpaca');

Ung.Alpaca.Util = {
    stopLoadingObject  : {},

    loadScript : function( queryPath, handler, failure )
    {
        var src = this.getQueryPathScript( queryPath );

        /* Now build the query */
        return Ext.Ajax.request({
            url : src,
            success : this.loadScriptSuccess.createDelegate( this, [ handler ], true ),
            failure : this.loadScriptFailure.createDelegate( this, [ failure ], true )
        });
    },

    loadScriptSuccess : function( response, options, handler )
    {
        var error = null;

        try {
            if( window.execScript) {
                window.execScript(response.responseText);
            } else {
                window.eval(response.responseText);
            }
        } catch ( e ) {
            if ( e != this.stopLoadingObject ) {
                throw e;
            }
        }
        
        handler( response, options );
    },

    loadScriptFailure : function( response, options, handler )
    {
        if ( handler != null ) {
            return handler( response, options );
        }

        throw "Unable to load script";
    },

    /**
     * @param path : The path to the request.
     * @param handler : Callback to call on success.
     * @param failure : Callback to call on failure.
     * @param *args : All arguments after this will be converted to an array and passed into
     *                the request as JSON.
     */
    executeRemoteFunction : function( path, handler, failure )
    {
        var args = [];
        var argumentCount = arguments.length;
        for ( var c = 3 ; c < argumentCount ; c++ ) {
            args[c-3] = arguments[c];
        }

        path = "/alpaca" + path;

        /* Now build the query */
        return Ext.Ajax.request({
            url : path,
            success : this.remoteFunctionSuccess.createDelegate( this, [ handler, failure ], true ),
            failure : this.remoteFunctionFailure.createDelegate( this, [ failure ], true ),
            jsonData : args
        });
    },
    
    remoteFunctionSuccess : function( response, options, handler, failure )
    {
        var json = Ext.util.JSON.decode( response.responseText );

        if ( json["status"] != "success" ) {
            return this.remoteFunctionFailure( response, options, failure );
        }
        
        handler( json["result"], response, options );
    },
    
    remoteFunctionFailure : function( response, options, handler )
    {
        if ( handler ) {
            return handler( response, options );
        }
        
        this.handleConnectionError( response, options );
    },

    handleConnectionError : function( response, options )
    {
        throw "Unable to connect";
    },

    stopLoading : function()
    {
        throw this.stopLoadingObject;
    },

    getQueryPathScript : function( queryPath )
    {
        return "/alpaca/javascripts/pages/" + queryPath["controller"] + "/" + queryPath["page"] + ".js";
    },

    /* Only update config if a value doesn't exist, extjs already has this
     * in ApplyIf. */
    updateDefaults : function( config, defaults )
    {
        for ( key in defaults ) {
            if ( config[key] == null ) {
                var value = defaults[key];
                if (( typeof value ) == "function" ) {
                    config[key] = defaults[key]();
                } else {
                    config[key] = defaults[key];
                }
            }
        }
    },

    implementMe : function( feature )
    {
        Ext.MessageBox.show({
            title : 'Implement Me',
            msg : feature,
            buttons : Ext.MessageBox.OK,
            icon : Ext.MessageBox.INFO
        });
    }
};

Ung.Alpaca.TextField = Ext.extend( Ext.form.TextField, {
    onRender : function(ct, position)
    {
        Ung.Alpaca.TextField.superclass.onRender.call(this, ct, position);
        
        var parent = this.el.parent()
        
        if( this.boxLabel ) {
            this.labelEl = parent.createChild({
                tag: 'label',
                htmlFor: this.el.id,
                cls: 'x-form-textfield-label',
                html: this.boxLabel
            });
        }
    }
});

/* override the default text field so that all of the text fields can add a box label */
Ext.reg('textfield', Ung.Alpaca.TextField);

Ung.Alpaca.ComboBox = Ext.extend( Ext.form.ComboBox, {
    onRender : function(ct, position)
    {
        Ung.Alpaca.ComboBox.superclass.onRender.call(this, ct, position);

        if( this.boxLabel ) {
            this.labelEl = this.wrap.createChild({
                tag: 'label',
                htmlFor: this.el.id,
                cls : 'x-form-combo-label',
                html : this.boxLabel
            });
        }
    }
});

/* override the default Combo box so that all of the comboboxes can add a box label */
Ext.reg('combo',  Ung.Alpaca.ComboBox);

