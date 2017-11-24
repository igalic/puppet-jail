class jail::setup::libiocage {

  file { '/usr/local/src':
    ensure => 'directory',
  }

  -> vcsrepo { '/usr/local/src/libiocage':
    ensure   => 'latest',
    provider => 'git',
    source   => 'https://github.com/iocage/libiocage',
    revision => 'master',
  }
  ~> exec { '/usr/bin/make install':
    refreshonly => true,
  }
}
