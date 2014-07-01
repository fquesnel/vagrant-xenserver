require "log4r"
require "xmlrpc/client"
require "vagrant-xenserver/util/uploader"
require "rexml/document"
require "json"

module VagrantPlugins
  module XenServer
    module Action
      class CreateVM
        def initialize(app, env)
          @app = app
          @logger = Log4r::Logger.new("vagrant::xenserver::actions::create_vm")
        end
        
        def call(env)
          vdi_ref = env[:my_vdi]
          
          networks = env[:xc].call("network.get_all_records",env[:session])['Value']

          himn = networks.find { |ref,net| net['other_config']['is_host_internal_management_network'] }
          (himn_ref,himn_rec) = himn

          @logger.info("himn_uuid="+himn_rec['uuid'])

          oim = env[:xc].call("VM.get_by_name_label",env[:session],"Other install media")['Value'][0]

          vm_ref = env[:xc].call("VM.clone",env[:session],oim,env[:machine].box.name.to_s)['Value']

          vbd_record = {
            'VM' => vm_ref,
            'VDI' => env[:box_vdi],
            'userdevice' => '0',
            'bootable' => true,
            'mode' => 'RW',
            'type' => 'Disk',
            'unpluggable' => false,
            'empty' => false,
            'other_config' => {},
            'qos_algorithm_type' => '',
            'qos_algorithm_params' => {}
          }

          vbd_res = env[:xc].call("VBD.create",env[:session],vbd_record)
          
          @logger.info("vbd_res=" + vbd_res.to_s)

          vif_record = {
            'VM' => vm_ref,
            'network' => himn_ref,
            'device' => '0',
            'MAC' => '',
            'MTU' => '1500',
            'other_config' => {},
            'qos_algorithm_type' => '',
            'qos_algorithm_params' => {},
            'locking_mode' => 'network_default',
            'ipv4_allowed' => [],
            'ipv6_allowed' => []
          }

          vif_res = env[:xc].call("VIF.create",env[:session],vif_record)
          
          @logger.info("vif_res=" + vif_res.to_s)

          env[:xc].call("VM.provision",env[:session],vm_ref)

          env[:machine].id = vm_ref

          @app.call env
        end
      end
    end
  end
end
