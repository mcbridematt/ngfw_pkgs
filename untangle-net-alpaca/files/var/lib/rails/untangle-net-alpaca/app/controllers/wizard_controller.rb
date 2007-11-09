class WizardController < ApplicationController
  InterfaceKey = "interface-config"

  ## This is the method helpers use to dynamically add stages
  ## to the wizard.
  InsertStagesMethod = "wizard_insert_stages"

  SaveMethod = "wizard_save"

  def index
    @title = "Setup Wizard"

    ## This should be in a global place
    @cidr_options = OSLibrary::NetworkManager::CIDR.map { |k,v| [ format( "%-3s %s", k, v ) , k ] }

    @cidr_options.sort! { |a,b| a[1].to_i <=> b[1].to_i }

    @builder = Alpaca::Wizard::Builder.new( Alpaca::Wizard::Stage )

    ## Iterate all of the helpers in search of stages for the wizard
    iterate_components do |component|
      next unless component.methods.include?( InsertStagesMethod )
      component.send( InsertStagesMethod, @builder )
    end
  end
  
  def save
    ## Iterate all of the components in search of stages for the wizard
    iterate_components do |component|
      next unless component.methods.include?( SaveMethod )
      component.send( SaveMethod )
    end
    
    ## Should be in the wizard manager
    spawn { os["network_manager"].commit }
  end
end
