FROM centos:7

# EPELを導入しておく + yum update + editor install
RUN echo "include_only=.jp" >> /etc/yum/pluginconf.d/fastestmirror.conf && \
    yum -q clean all && \
    yum -y -q install epel-release && \
    yum -y -q update && \
    rm -f /etc/rpm/macros.image-language-conf && \
    sed -i '/^override_install_langs=/d' /etc/yum.conf && \
    yum reinstall -y -q glibc-common && \
    yum -y -q groupinstall "Development Tools" && \
    yum install -y -q wget vim kbd ibus-kkc vlgothic-* && \
    yum -q clean all

# set ENV
ENV container docker
ENV LANG ja_JP.UTF-8
ENV LANGUAGE ja_JP:ja
ENV LC_ALL ja_JP.UTF-8
ENV GIT_VERSION 2.26.2

RUN localedef -f UTF-8 -i ja_JP ja_JP.UTF-8 && \
    echo 'LANG="ja_JP.UTF-8"' >  /etc/locale.conf && \
    echo 'ZONE="Asia/Tokyo"' > /etc/sysconfig/clock && \
    unlink /etc/localtime && \
    ln -s /usr/share/zoneinfo/Japan /etc/localtime

WORKDIR /usr/local/src
RUN yum remove -y git \
    && yum install -y curl-devel expat-devel gettext-devel openssl-devel zlib-devel perl-ExtUtils-MakeMaker \
    && wget https://mirrors.edge.kernel.org/pub/software/scm/git/git-${GIT_VERSION}.tar.gz \
    && tar xvzf git-${GIT_VERSION}.tar.gz \
    && cd git-${GIT_VERSION} \
    && make prefix=/usr/local all \
    && make prefix=/usr/local install

RUN yum install -y ansible systemd libselinux-python selinux-policy && yum clean all

# CIテスト用にsystemdを有効にする
RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == \
    systemd-tmpfiles-setup.service ] || rm -f $i; done); \
    rm -f /lib/systemd/system/multi-user.target.wants/*;\
    rm -f /etc/systemd/system/*.wants/*;\
    rm -f /lib/systemd/system/local-fs.target.wants/*; \
    rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
    rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
    rm -f /lib/systemd/system/basic.target.wants/*;\
    rm -f /lib/systemd/system/anaconda.target.wants/*;
VOLUME [ "/sys/fs/cgroup" ]

# CIサーバーからsshの警告が出ないように設定を追加する
ADD ansible.cfg /etc/ansible/ansible.cfg
# CIサーバーが国内なのでJP限定にする
ADD fastestmirror.conf /etc/yum/pluginconf.d/fastestmirror.conf

# AWS CLI使うことが多いので入れる
RUN yum install -y https://centos7.iuscommunity.org/ius-release.rpm && \
    yum install -y python36u python36u-libs python36u-devel python36u-pip && \
    curl -kL https://bootstrap.pypa.io/get-pip.py | python3.6 && \
    pip3.6 install awscli && \
    yum -q clean all

# go使いたいので入れる
ENV GOROOT /usr/lib/golang
ENV GOPATH /usr/local
ENV PATH $PATH:$GOROOT/bin:$GOPATH/bin
RUN yum install -y golang && \
    yum -q clean all

# filelint入れる
RUN go get -u github.com/synchro-food/filelint

# ruby入れる
RUN yum -y install make tar git wget gcc-c++ openssl-devel readline-devel gdbm-devel libffi-devel zlib-devel curl-devel procps autoconf sudo && yum -q clean all \
  && git clone https://github.com/sstephenson/rbenv.git /usr/local/rbenv \
  && mkdir /usr/local/rbenv/shims /usr/local/rbenv/versions /usr/local/rbenv/plugins \
  && groupadd rbenv \
  && chgrp -R rbenv /usr/local/rbenv \
  && chmod -R g+rwxXs /usr/local/rbenv \
  && git clone https://github.com/sstephenson/ruby-build.git /usr/local/rbenv/plugins/ruby-build \
  && chgrp -R rbenv /usr/local/rbenv/plugins/ruby-build \
  && chmod -R g+rwxs /usr/local/rbenv/plugins/ruby-build \
  && /usr/local/rbenv/plugins/ruby-build/install.sh \
  && git clone https://github.com/sstephenson/rbenv-default-gems.git /usr/local/rbenv/plugins/rbenv-default-gems \
  && chgrp -R rbenv /usr/local/rbenv/plugins/rbenv-default-gems \
  && chmod -R g+rwxs /usr/local/rbenv/plugins/rbenv-default-gems \
  && echo 'export RBENV_ROOT="/usr/local/rbenv"' >> /etc/profile.d/rbenv.sh \
  && echo 'export PATH="/usr/local/rbenv/bin:$PATH"' >> /etc/profile.d/rbenv.sh \
  && echo 'eval "$(rbenv init -)"' >> /etc/profile.d/rbenv.sh \
  && echo '%rbenv ALL=(ALL) ALL' >> /etc/sudoers \
  && su -l root -c '/usr/local/rbenv/bin/rbenv install 2.6.1 -v' \
  && su -l root -c '/usr/local/rbenv/bin/rbenv rehash' \
  && su -l root -c '/usr/local/rbenv/bin/rbenv global 2.6.1'

# CI内からちょっとスクリプト動かしたくてそこで必要なjqを入れる
RUN yum install -y jq

# ansible-lint入れる
RUN pip install ansible-lint

RUN mkdir /root/.ssh
COPY config /root/.ssh/config

CMD ["/usr/sbin/init"]
