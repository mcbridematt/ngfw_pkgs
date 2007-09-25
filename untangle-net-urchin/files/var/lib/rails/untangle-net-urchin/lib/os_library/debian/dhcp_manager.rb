## REVIEW : This is not legit
require_dependency "os_library/debian/network_manager"

class OSLibrary::Debian::DhcpManager < OSLibrary::DhcpManager
  include Singleton
  
  ConfigDir = "/etc/untangle-net-urchin"
  ConfigFileBase = "dhcp-overrides."

  OverrideIPAddress = "DHCP_IP_ADDRESS"
  OverrideNetmask = "DHCP_IP_NETMASK"
  OverrideGateway = "DHCP_GATEWAY"
  OverrideDnsServer = "DHCP_DNS_SERVERS"
  OverrideDomainName = "DHCP_DOMAIN_NAME"
  
  def commit
    ## Delete all of the existing config files
    delete_config_files

    ## Write out all of the config files
    write_config_files
  end

  private
  ## Delete all of the config files, this guarantees there
  ## are no leftover configuration files when an interface goes from Dynamic -> Static
  def delete_config_files
    Dir.foreach( ConfigDir ) do |file_name|
      next if file_name.match( /^#{ConfigFileBase}/ ).nil?
      ## REVIEW : This has to interact with the file manager
      FileUtils.rm( "#{ConfigDir}/#{file_name}", :force => true )
    end
  end

  def write_config_files
    Interface.find( :all ).each do |interface|
      config = interface.current_config
      
      ## Ignore anything that is not dynamic
      next unless config.is_a?( IntfDynamic )
      
      ## Don't like this code living in multiple places
      name = interface.os_name
      name = OSLibrary::Debian::NetworkManager.bridge_name( interface ) if interface.is_bridge?
      
      cfg = [ header ]

      ## REVIEW how to handle search domain
      ## [ OverrideDomainName, [ config.dns_1, config.dns_2 ].join( " " ).strip ]]
      
      [[ OverrideIPAddress, config.ip ],
       [ OverrideNetmask, config.netmask ], 
       [ OverrideGateway, config.default_gateway ],
       [ OverrideDnsServer, [ config.dns_1, config.dns_2 ].join( " " ).strip ]].each do |var,val|
        next if ( val.nil? || val.empty? )
        cfg << "#{var}=#{val}"
      end
      
      next if cfg.size == 1
      
      file_name = "#{ConfigDir}/#{ConfigFileBase}#{name}"
      File.open( file_name, "w" ) { |f| f.print( cfg.join( "\n" ), "\n" ) }
    end
  end

  def header
    <<EOF
#!/bin/dash
## Auto Generated by the Untangle Net Urchin
## If you modify this file manually, your changes
## may be overriden
EOF
  end
end
