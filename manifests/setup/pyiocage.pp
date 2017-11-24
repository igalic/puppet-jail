# This 
class jail::setup::pyiocage {
  package { 'iocage':
    ensure => installed,
  }

  service { 'iocage':
    enable => true,
  }

  file { '/etc/jail.conf':
    ensure => absent,
  }

  File['/etc/jail.conf'] ~> Service['iocage']
  Package['iocage'] ~> Service['iocage']

}
