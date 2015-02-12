# Author::    Liam Bennett (mailto:lbennett@opentable.com)
# Copyright:: Copyright (c) 2013 OpenTable Inc
# License::   MIT

# == Class rundeck::install
#
# This private class installs the rundeck package and it's dependencies
#
class rundeck::install(
  $jre_name           = $rundeck::jre_name,
  $jre_ensure         = $rundeck::jre_ensure,
  $jre_manage         = $rundeck::jre_manage,
  $package_source     = $rundeck::package_source,
  $package_ensure     = $rundeck::package_ensure,
  $manage_yum_repo    = $rundeck::manage_yum_repo,
  $rdeck_home         = $rundeck::rdeck_home,
  $rdeck_base         = $rundeck::rdeck_base
) {

  if $caller_module_name != $module_name {
    fail("Use of private class ${name} by ${caller_module_name}")
  }

  $framework_config = deep_merge($rundeck::params::framework_config, $rundeck::framework_config)
  $projects_dir = $framework_config['framework.projects.dir']
  $plugin_dir = $framework_config['framework.libext.dir']

  if $jre_manage {
    ensure_resource('package', $jre_name, {'ensure' => $jre_ensure} )
  }

  $user = $rundeck::user
  $group = $rundeck::group

  File { 
    require => Package['rundeck']
  }

  case $::osfamily {
    'RedHat': {
      if $manage_yum_repo == true {
        yumrepo { 'bintray-rundeck':
          baseurl  => 'http://dl.bintray.com/rundeck/rundeck-rpm/',
          descr    => 'bintray rundeck repo',
          enabled  => '1',
          gpgcheck => '0',
          priority => '1',
          before   => Package['rundeck'],
        }
      }

      ensure_resource('package', 'rundeck', {'ensure' => $package_ensure} )
    }
    'Debian': {

      $version = inline_template("<% package_version = '${package_ensure}' %><%= package_version.split('-')[0] %>")

      if $::rundeck_version != $version {
        exec { 'download rundeck package':
          command => "/usr/bin/wget ${package_source}/rundeck-${package_ensure}.deb -O /tmp/rundeck-${package_ensure}.deb",
          unless  => "/usr/bin/test -f /tmp/rundeck-${package_ensure}.deb"
        }

        exec { 'stop rundeck service':
          command => '/usr/sbin/service rundeckd stop',
          unless  => "/bin/bash -c 'if ps ax | grep -v grep | grep RunServer > /dev/null; then echo 1; else echo 0; fi'"
        }

        exec { 'install rundeck package':
          command => "/usr/bin/dpkg --force-confold -i /tmp/rundeck-${package_ensure}.deb",
          unless  => "/usr/bin/dpkg -l | grep rundeck | grep ${version}",
          require => [ Exec['download rundeck package'], Exec['stop rundeck service'], Package[$jre_name] ]
        }
      }

    }
    default: {
      err("The osfamily: ${::osfamily} is not supported")
    }
  }
  file { $rdeck_home:
    ensure => directory,
    owner  => $user,
    group  => $group,
    mode   => '0755',
  }

  file { $rdeck_base:
    ensure => directory,
    owner  => $user,
    group  => $group,
    mode   => '0755',
  }

  file { $plugin_dir:
    ensure  => directory,
    owner   => $user,
    group   => $group,
    mode    => '0755',
    require => File[$rdeck_base],
  }

  ensure_resource(file, $projects_dir, {'ensure' => 'directory', 'owner' => $user, 'group' => $group})
}
