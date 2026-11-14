ARG BUILD_FROM
FROM worldvista/vehu:202609@sha256:e0710df4ab487831ad84d0383637488da2baa37168ce8ac8e71e8cd039590622

# Labels for HA add-on
LABEL \
    io.hass.name="VistA EHR Server" \
    io.hass.description="VistA EHR with VEHU training database and VAAES nursing templates" \
    io.hass.type="addon" \
    io.hass.version="1.0.7"

# Boot script and patch scripts
COPY run.sh /run.sh
COPY patch_xusrb.py /patch_xusrb.py
COPY patch_gmtsobj.py /patch_gmtsobj.py
COPY import_prd.py /import_prd.py

# M routines: patched Reminder Exchange installer + provisioning routines (all idempotent)
COPY listusers.m /home/vehu/r/listusers.m
COPY prdimport.m /home/vehu/r/prdimport.m
COPY PXRMEXIU.m /home/vehu/r/PXRMEXIU.m
COPY PXRMEXIC.m /home/vehu/r/PXRMEXIC.m
COPY PXRMEXU4.m /home/vehu/r/PXRMEXU4.m
COPY vaaesfix.m /home/vehu/r/vaaesfix.m
COPY setupnote.m /home/vehu/r/setupnote.m
COPY linkdlg.m /home/vehu/r/linkdlg.m
COPY fixdlgauth.m /home/vehu/r/fixdlgauth.m
COPY mdclio.m /home/vehu/r/mdclio.m
COPY cpfsver.m /home/vehu/r/cpfsver.m
COPY mhadll.m /home/vehu/r/mhadll.m
# Not run at boot (mumps -run nbmcpset): NursingBooster MCP bridge context option + COM object for TDNURSE,ONE
COPY nbmcpset.m /home/vehu/r/nbmcpset.m
COPY prd-files/ /prd-files/

# Fix line endings and set permissions
RUN sed -i 's/\r$//' /run.sh /patch_xusrb.py /patch_gmtsobj.py /import_prd.py /home/vehu/r/*.m /prd-files/*.PRD && \
    chmod a+x /run.sh /patch_xusrb.py /patch_gmtsobj.py /import_prd.py && \
    chown vehu:vehu /home/vehu/r/*.m

# SSH: enable password auth + install SSH keys for passwordless access (vehu/vehu, root/root)
RUN sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null; \
    sed -i 's/^#PasswordAuthentication/PasswordAuthentication/' /etc/ssh/sshd_config 2>/dev/null; \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config; \
    echo 'vehu:vehu' | chpasswd 2>/dev/null; \
    echo 'root:root' | chpasswd 2>/dev/null; \
    mkdir -p /root/.ssh /home/vehu/.ssh && \
    for k in \
      'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOJJKBmiXkEmIJjwuUK1M4hwjlv+NSHvq95HY0LWOCyu' \
      'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGqt6FOQvfGP+cuKrP4f/Lf2hArYiTtUCEmCLGhQ70uE'; do \
      echo "$k" >> /root/.ssh/authorized_keys; echo "$k" >> /home/vehu/.ssh/authorized_keys; done && \
    chmod 700 /root/.ssh /home/vehu/.ssh && \
    chmod 600 /root/.ssh/authorized_keys /home/vehu/.ssh/authorized_keys && \
    chown -R vehu:vehu /home/vehu/.ssh; \
    true

# Override entrypoint so our run.sh actually executes
ENTRYPOINT []

# Expose RPC Broker, web, SSH, YDB GUI
EXPOSE 9430 8001 22 8089

CMD ["/run.sh"]
