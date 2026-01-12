FROM rakudo-star:latest
LABEL maintainer="Dr Suman Khanal <suman81765@gmail.com>"


#Enabling Binder..................................
ENV NB_USER suman
ENV NB_UID 1000
ENV HOME /home/${NB_USER}
RUN adduser --disabled-password \
    --gecos "Default user" \
    --uid ${NB_UID} \
    ${NB_USER}

#..............................................

ENV PATH=$PATH:/usr/share/perl6/site/bin

RUN apt-get update \
    && apt-get install -y build-essential tini wget libzmq3-dev ca-certificates \
       python3-setuptools jupyter jupyter-notebook asciinema jupyterhub openssl libssl-dev
RUN zef install SVG::Plot OpenSSL --force-test
RUN zef -v install git://github.com/antononcube/Raku-Jupyter-Chatbook.git \
    && jupyter-chatbook-raku --generate-config --force \
    && ln -s /usr/share/perl6/site/bin/* /usr/local/bin

ENTRYPOINT ["/usr/bin/tini", "--"]

#For enabling binder..........................
COPY eg ${HOME}

USER root
RUN chown -R ${NB_UID} ${HOME}
USER ${NB_USER}
WORKDIR ${HOME}
#..............................................

EXPOSE 8888

CMD ["jupyter", "notebook", "--port=8888", "--no-browser", "--ip=0.0.0.0", "--allow-root"]
