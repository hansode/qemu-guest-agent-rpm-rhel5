#!/bin/bash
#
#
#
set -e
set -x

declare chroot_dir=$1

chroot $1 $SHELL -ex <<'EOS'
  pkg_name=qemu-kvm
  pkg_ver=0.12.1.2
  srpm_file=${pkg_name}-${pkg_ver}-2.355.el6.src.rpm

  cd /root

  [[ -f "${srpm_file}" ]] || {
    curl -fkL -O http://vault.centos.org/6.4/os/Source/SPackages/${srpm_file}
  }

  mkdir -p rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
  cat <<-'EOF' > /root/.rpmmacros
	%_topdir /root/rpmbuild
	%_sysconfdir /etc
	EOF

  # presetup
  yum install -y --disablerepo=* --enablerepo=base \
   rpm-build \
   gcc zlib-devel glib2-devel \
   SDL-devel zlib-devel which texi2html gnutls-devel cyrus-sasl-devel \
   rsync dev86 iasl \
   pciutils-devel \
   ncurses-devel \
   libaio-devel \
   systemtap-sdt-devel \
   systemtap

  # setup
  cd /root/rpmbuild/SOURCES/
  rpm2cpio /root/${srpm_file} | cpio -id

  # pache
  cd /root/rpmbuild/SPECS/
  rpm2cpio /root/${srpm_file} | cpio -id qemu-kvm.spec
  sed -i "s,^BuildRequire,#BuildRequire," qemu-kvm.spec
  rpmbuild -bp qemu-kvm.spec

  # build
  cd /root/rpmbuild/BUILD/${pkg_name}-${pkg_ver}
  ./configure
  make qemu-ga

  # install
  install -m 755 qemu-ga           /usr/bin/qemu-ga
  cd /root/rpmbuild/SOURCES/
  install -m 755 qemu-ga.init      /etc/rc.d/init.d/qemu-ga
  install -m 644 qemu-ga.sysconfig /etc/sysconfig/qemu-ga

  # test
  chkconfig --add  qemu-ga
  chkconfig --list qemu-ga
  chkconfig qemu-ga off
  chkconfig --list qemu-ga

  # package
  cd /
  tar cpf /tmp/qemu-guest-agent-rhel5.tar /usr/bin/qemu-ga /etc/rc.d/init.d/qemu-ga /etc/sysconfig/qemu-ga
EOS

[[ -d pkg ]] || mkdir pkg
rsync -avx ${chroot_dir}/tmp/qemu-guest-agent-rhel5.tar ./pkg/.
bash -c 'chown -R ${SUDO_UID}:${SUDO_GID} pkg'
