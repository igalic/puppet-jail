# Class: jail::setup
#
# Lay down the global configuration for jail.conf as well as create the needed
# directories and/or zfs mountpoints.
#
class jail::setup (
  String $jail_pool,
  Jail::Flavor $flavor = 'libiocage',
) {

  contain "jail::setup::${flavor}"

  $binary = $flavor ?  {
    'iocell'        => '/usr/local/sbin/iocell',
    'iocage_legacy' => '/usr/local/sbin/iocage',
    'libiocage'     => '/usr/local/bin/ioc -d error',
    default         => '/usr/local/bin/iocage',
  }

  exec { "${binary} ${jail_pool}":
    refreshonly => true,
  }
}
