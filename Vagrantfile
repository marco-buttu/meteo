# frozen_string_literal: true

VAGRANT_BOX = ENV.fetch('VAGRANT_BOX', 'ubuntu/jammy64')
HOST_DATA_DIR = ENV['HOST_DATA_DIR']
GUEST_DATA_DIR = ENV.fetch('GUEST_DATA_DIR', '/dati')
HOST_APP_PORT = ENV.fetch('HOST_APP_PORT', '5000').to_i
VM_MEMORY = ENV.fetch('VM_MEMORY', '4096').to_i
VM_CPUS = ENV.fetch('VM_CPUS', '2').to_i

COMMANDS_REQUIRING_DATA_DIR = %w[up provision reload].freeze
REQUIRES_DATA_DIR = (ARGV & COMMANDS_REQUIRING_DATA_DIR).any?
HAS_DATA_DIR = !HOST_DATA_DIR.nil? && !HOST_DATA_DIR.strip.empty?

if REQUIRES_DATA_DIR && !HAS_DATA_DIR
  raise 'HOST_DATA_DIR is required for this command. Example: HOST_DATA_DIR=/home/marco/wrf/data vagrant up'
end

if HAS_DATA_DIR && !File.directory?(HOST_DATA_DIR)
  raise "HOST_DATA_DIR does not exist or is not a directory: #{HOST_DATA_DIR}"
end

Vagrant.configure('2') do |config|
  config.vm.box = VAGRANT_BOX
  config.vm.hostname = 'meteo-vm'

  config.vm.network 'forwarded_port', guest: 5000, host: HOST_APP_PORT, auto_correct: false

  config.vm.synced_folder '.', '/vagrant', type: 'virtualbox'

  if HAS_DATA_DIR
    config.vm.synced_folder HOST_DATA_DIR, GUEST_DATA_DIR,
                            create: false,
                            owner: 'vagrant',
                            group: 'vagrant',
                            mount_options: ['dmode=755', 'fmode=644']
  end

  config.vm.provider 'virtualbox' do |vb|
    vb.name = 'meteo-vagrant'
    vb.memory = VM_MEMORY
    vb.cpus = VM_CPUS
  end

  config.vm.provision 'shell',
                      path: 'scripts/deployment/virtualbox/provision_vm.sh',
                      env: {
                        'GUEST_DATA_DIR' => GUEST_DATA_DIR,
                        'METEO_RUN_USER' => 'vagrant',
                        'METEO_RUN_GROUP' => 'vagrant'
                      }
end
