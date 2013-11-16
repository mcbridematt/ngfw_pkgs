#
# $HeadURL: svn://chef/work/pkgs/untangle-net-alpaca/files/var/lib/rails/untangle-net-alpaca/lib/os_library/pppoe_manager.rb $
# Copyright (c) 2007-2008 Untangle, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2,
# as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but
# AS-IS and WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE, TITLE, or
# NONINFRINGEMENT.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
#
class OSLibrary::Null::PppoeManager < OSLibrary::PppoeManager
  include Singleton

  ## xxx presently only support one connection xxx
  ProviderName = "connection0"
  PeersFile = "/etc/ppp/peers/#{ProviderName}"
  PapSecretsFile = "/etc/ppp/pap-secrets"


  def register_hooks
    os["network_manager"].register_hook( -100, "pppoe_manager", "write_files", :hook_write_files )
  end
  
  def hook_write_files
    ## Find the WAN interface that is configured for PPPoE.
    ## xxx presently PPPoE is only supported on the WAN interface xxx
    conditions = [ "wan=? and config_type=?", true, InterfaceHelper::ConfigType::PPPOE ]
    wan_interface = Interface.find( :first, :conditions => conditions )
    
    ## No PPPoE interface is available.
    return if wan_interface.nil?

    ## Retrieve the pppoe settings from the wan interface
    settings = wan_interface.current_config

    ## Verify that the settings are actually available.
    return if settings.nil? || !settings.is_a?( IntfPppoe )
    
    cfg = []
    secrets = []

    cfg << <<EOF
#{header}
noipdefault
hide-password
noauth
persist
maxfail 0
EOF

    cfg << "defaultroute"
    cfg << "replacedefaultroute"
    cfg << "usepeerdns" if ( settings.use_peer_dns )

    ## Use the PPPoE daemon and the current interface.
    cfg << "plugin rp-pppoe.so #{wan_interface.os_name}"

    ## Create a comment containing the list of "bridged" interfaces for the UVM and
    ## the name of the bridge, makes reloading the networking configuration easy.
    ## XXXX IMPORTANT DATA IN COMMENTS NOT LEGIT XXXX
    if wan_interface.is_bridge?
      bridge_name = OSLibrary::Debian::NetworkManager.bridge_name( wan_interface )
      bia = wan_interface.bridged_interface_array.map{ |i| i.os_name }
      cfg << "# bridge_configuration: #{bridge_name} #{bia.join(",")}"
    end

    ## Append the username
    cfg << "user \"#{settings.username}\""

    ## Append anything that is inside of the secret field for the PPPoE Configuration
    secret_field = settings.secret_field
    cfg << settings.secret_field unless secret_field.nil?

    secrets << "\"#{settings.username}\" *  \"#{settings.password}\""   
  
    ## This limits us to one connection, hardcoding to 0 for now.
    os["override_manager"].write_file( PeersFile, cfg.join( "\n" ), "\n" )
    os["override_manager"].write_file( PapSecretsFile, header, "\n", secrets.join( "\n" ), "\n" )
  end
  
  def header
    <<EOF
## #{Time.new}
## Auto Generated by the Untangle Net Alpaca
## If you modify this file manually, your changes
## may be overriden
EOF
  end
end