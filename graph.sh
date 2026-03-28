    # Graph for provisioning
          ansible-playbook-grapher \
            playbooks/provision.yml \
            -o docs/provision-graph \

          # Graph for installing k0s master
          ansible-playbook-grapher \
            playbooks/k8s-install.yml \
            -o docs/k8s-install-graph \

          # Graph for joining workers
          ansible-playbook-grapher \
            playbooks/k8s-join.yml \
            -o docs/k8s-join-graph \

          # Graph for addons
          ansible-playbook-grapher \
            playbooks/k8s-addons.yml \
            -o docs/k8s-addons-graph \

          # Graph for verification
          ansible-playbook-grapher \
            playbooks/verify.yml \
            -o docs/verify-graph \
