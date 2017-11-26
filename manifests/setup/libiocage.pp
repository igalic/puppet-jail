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
    cwd         => '/usr/local/src/libiocage',
    refreshonly => true,
  }

  -> service { 'ioc':
    ensure => 'running',
    enable => true,
  }
}
