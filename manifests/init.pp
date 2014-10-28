class ispconfig_named {
  $syslogdef    = '/etc/default/syslogd'
  $bindir       = '/etc/bind'
  $initscript   = '/etc/init.d/bind9'
  $defaultbind9 = '/etc/default/bind9'
  $defaultconf  = 'ispconfig_named/defaultbind9'
  $bindchroot   = '/var/lib/named'
  $binpath      = ' /usr/sbin/named'
  $binduserhome = '/var/cache/bind'

  File {
    owner => 'bind',
    group => 'bind'
  }

  package { 'bind9':
    ensure  => present,
  }

  exec { 'stop':
    command => "sudo ${initscript} stop",
    onlyif	=> ["test ! -h ${bindir}"],
    require	=> Package['bind9'],
    before	=> Exec['start'],
  }

  exec { 'defaultbind9-backup':
    command => "sudo cp ${defaultbind9} ${defaultbind9}.bak",
    onlyif  => ["test -n \"`diff -q ${defaultbind9} ${defaultbind9}.bak 2>&1`\""],
  }

  exec { 'defaultbind9-restart':
    command => "sudo ${initscript} restart",
    onlyif  => ["test -n \"`diff -q ${defaultbind9} ${defaultbind9}.bak 2>&1`\""],
    before  => Exec['defaultbind9-backup'],
    require => [ Class['apparmor'], Package['bind9'], ]
  }

  file { $defaultbind9:
    ensure  => present,
    mode		=> '0644',
    owner		=> 'root',
    group		=> 'root',
    source	=> "puppet:///modules/${defaultconf}",
    require => Package['bind9'],
    before  => Exec['start'],
  }

  file { $bindchroot:
    ensure  => directory,
    before  => Exec['start'],
    require => [ Package['bind9'], Exec['adduser-bind'] ],
  }

  file { "${bindchroot}/etc":
    ensure  => directory,
    before  => Exec['start'],
    require => [ Package['bind9'], Exec['adduser-bind'] ],
  }

  file { "${bindchroot}/dev":
    ensure  => directory,
    before  => Exec['start'],
    require => [ Package['bind9'], Exec['adduser-bind'] ],
  }

  file { "${bindchroot}/var":
    ensure  => directory,
    before  => Exec['start'],
    require => [ Package['bind9'], Exec["adduser-bind"] ],
  }

  file { "${bindchroot}/var/cache":
    ensure  => directory,
    before  => Exec['start'],
    require => [ Package['bind9'], Exec['adduser-bind'] ],
  }

  file { "${bindchroot}/var/cache/bind":
    ensure  => directory,
    before  => Exec['start'],
    require => [ Package['bind9'], Exec['adduser-bind'] ],
  }

  file { "${bindchroot}/var/run":
    ensure  => directory,
    before  => Exec['start'],
    require => [ Package['bind9'], Exec['adduser-bind'] ],
  }

  file { "${bindchroot}/var/run/bind":
    ensure  => directory,
    before  => Exec['start'],
    require => [ Package['bind9'], Exec['adduser-bind'] ],
  }

  file { "${bindchroot}/var/run/bind/run":
    ensure  => directory,
    before  => Exec['start'],
    require => [ Package['bind9'], Exec['adduser-bind'] ],
  }

  file { "${bindchroot}/etc/bind":
    ensure  => directory,
    before  => Exec['start'],
    require => [ Package['bind9'], Exec['adduser-bind'] ],
  }

  exec { 'moveconf':
    command	=> "sudo mv ${bindir}/* ${bindchroot}/etc/bind; sudo rmdir ${bindir} && sudo ln -s ${bindchroot}/etc/bind ${bindir}",
    onlyif	=> ["test ! -h ${bindir}"],
    require => [ Exec['stop'], File["${bindchroot}/etc/bind"] ],
    before  => Exec['start']
  }

  exec { 'mknod1':
    command	=> "sudo mknod ${bindchroot}/dev/null c 1 3",
    onlyif	=> ["test ! -c ${bindchroot}/dev/null"],
    require => File["${bindchroot}/dev"],
    before  => Exec['start'],
  }

  exec { 'mknod2':
    command => "sudo mknod ${bindchroot}/dev/random c 1 8",
    onlyif  => ["test ! -c ${bindchroot}/dev/random"],
    require => File["${bindchroot}/dev"],
    before  => Exec['start'],
  }

  exec { 'chmod':
    command	=> "sudo chmod 666 ${bindchroot}/dev/null ${bindchroot}/dev/random",
    onlyif	=> ["test \"`stat --printf=%a ${bindchroot}/dev/null`\" != \"666\"", "test \"`stat --printf=%a ${bindchroot}/dev/random`\" != \"666\""],
    require => [ Exec['mknod1'], Exec['mknod2'] ],
    before  => Exec['start'],
  }

  # creazione utente e gruppo 'bind'
  exec { 'adduser-bind':
    command => "sudo useradd -d ${binduserhome} -s /bin/false -K UID_MIN=100 -K UID_MAX=499 bind",
    onlyif	=> ['test -z "`grep -e \'^bind:.*\' /etc/passwd`"'],
  }

  exec { 'chown':
    command => "sudo chown -R bind:bind ${bindchroot}${bindir} ${bindchroot}/var/*",
    onlyif	=> ["test -n \"`find ${bindchroot}${bindir} ! -user bind`\" -o -n \"`find ${bindchroot}/var ! -user bind`\""],
    require => [ Exec['moveconf'], File["${bindchroot}/var/cache/bind"], File["${bindchroot}/var/run/bind/run"], Exec['adduser-bind'] ],
    before  => Exec['start'],
  }

  exec { 'start':
    command	=> "sudo ${initscript} start",
    onlyif	=> ["test -z \"`ps aux | grep ${binpath} | grep -v grep`\""],
    require => Class['apparmor'],
  }

  # solo per Hardy, configuriamo sysklogd
  case $::lsbdistcodename {

    'hardy': {

      file_line {'syslogd':
        ensure  => present,
        path    => '/etc/default/syslogd',
        line    => "SYSLOGD=\"-a ${bindchroot}/dev/log\"",
        match   => '^SYSLOGD=',
        before	=> [ Exec['sysklogd-restart'], Exec['start'] ],
      }

      exec { 'sysklogd-restart':
        command => 'sudo /etc/init.d/sysklogd restart',
        onlyif  => ["test -n \"`diff -q ${syslogdef} ${syslogdef}.bak 2>&1`\""],
        before  => [ Exec['start'], Exec['syslogd-backup'] ],
      }

      exec { 'syslogd-backup':
        command => "sudo cp ${syslogdef} ${syslogdef}.bak",
        onlyif  => ["test -n \"`diff -q ${syslogdef} ${syslogdef}.bak 2>&1`\""],
      }

    }

  }

}
