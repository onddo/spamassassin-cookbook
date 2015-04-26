# encoding: UTF-8
#
# Cookbook Name:: onddo-spamassassin
# Recipe:: default
# Author:: Xabier de Zuazo (<xabier@onddo.com>)
# Copyright:: Copyright (c) 2013-2015 Onddo Labs, SL. (www.onddo.com)
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

service_name = node['onddo-spamassassin']['spamd']['service_name']

user node['onddo-spamassassin']['spamd']['user'] do
  comment 'SpamAssassin Daemon'
  home node['onddo-spamassassin']['spamd']['lib_path']
  shell '/bin/false'
  system true
end

group node['onddo-spamassassin']['spamd']['group'] do
  members [node['onddo-spamassassin']['spamd']['user']]
  system true
  append true
end

node.default['onddo-spamassassin']['spamd']['options'] =
  node['onddo-spamassassin']['spamd']['options'] +
  [
    "--username=#{node['onddo-spamassassin']['spamd']['user']}",
    "--groupname=#{node['onddo-spamassassin']['spamd']['group']}"
  ]

execute 'sa-update' do
  case node['platform']
  when 'debian', 'ubuntu'
    command(
      format(
        "sa-update --gpghomedir '%<lib_path>s/sa-update-keys'",
        lib_path: node['onddo-spamassassin']['spamd']['lib_path']
      )
    )
  else
    command 'sa-update --no-gpg'
  end
  action :nothing
  notifies :restart, "service[#{service_name}]"
end

package 'spamassassin' do
  notifies :run, 'execute[sa-update]'
end

options = node['onddo-spamassassin']['spamd']['options']

case node['platform']
when 'redhat', 'centos', 'scientific', 'fedora', 'suse', 'amazon'

  template '/etc/sysconfig/spamassassin' do
    source 'sysconfig_spamassassin.erb'
    owner 'root'
    group 'root'
    mode '00644'
    variables(
      options: options,
      pidfile: node['onddo-spamassassin']['spamd']['pidfile'],
      nice: node['onddo-spamassassin']['spamd']['nice']
    )
    notifies :restart, "service[#{service_name}]"
  end

when 'debian', 'ubuntu'
  package 'spamc'

  template '/etc/default/spamassassin' do
    source 'default_spamassassin.erb'
    owner 'root'
    group 'root'
    mode '00644'
    variables(
      enabled: node['onddo-spamassassin']['spamd']['enabled'],
      options: options,
      pidfile: node['onddo-spamassassin']['spamd']['pidfile'],
      nice: node['onddo-spamassassin']['spamd']['nice']
    )
    notifies :restart, "service[#{service_name}]"
  end

end

execute 'fix-spamd-lib-owner' do
  command(
    format(
      "chown -R '%<user>s:%<group>s' '%<path>s'",
      user: node['onddo-spamassassin']['spamd']['user'],
      group: node['onddo-spamassassin']['spamd']['group'],
      path: node['onddo-spamassassin']['spamd']['lib_path']
    )
  )
  action :nothing
end

directory node['onddo-spamassassin']['spamd']['lib_path'] do
  owner node['onddo-spamassassin']['spamd']['user']
  group node['onddo-spamassassin']['spamd']['group']
  notifies :run, 'execute[fix-spamd-lib-owner]', :immediately
end

template '/etc/mail/spamassassin/local.cf' do
  source 'local.cf.erb'
  owner 'root'
  group 'root'
  mode '00644'
  variables(
    conf: node['onddo-spamassassin']['conf']
  )
  notifies :restart, "service[#{service_name}]"
end

if node['onddo-spamassassin']['spamd']['enabled']
  service service_name do
    supports restart: true, reload: true, status: true
    action [:enable, :start]
  end
else
  service service_name do
    supports restart: true, reload: false, status: true
    action [:disable, :stop]
  end
end
