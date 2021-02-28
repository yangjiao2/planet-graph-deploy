FROM docker.4pd.io/build-ansible:0.0.3

RUN mkdir /root/tmp_bin && mkdir /root/planet-graph-deploy && mkdir /root/planet-graph-deploy/tmp
RUN ls /root/tmp_bin
ADD /bin /root/tmp_bin


WORKDIR /root/planet-graph-deploy
ADD ansible.cfg site.yaml rollout.yaml clean.yaml scale_service.yaml inventory playbooks /root/planet-graph-deploy/


ENTRYPOINT ["/bin/bash", "-l", "-c"]