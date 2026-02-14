ARG BUILD_FROM
FROM worldvista/vehu:latest

# Labels for HA add-on
LABEL \
    io.hass.name="VistA EHR Server" \
    io.hass.description="VistA EHR with VEHU training database and VAAES nursing templates" \
    io.hass.type="addon" \
    io.hass.version="1.0.3"

# Copy all scripts, routines, and PRD files
COPY run.sh /run.sh
COPY patch_xusrb.py /patch_xusrb.py
COPY import_prd.py /import_prd.py
COPY patch_gmtsobj.py /patch_gmtsobj.py
COPY listusers.m /home/vehu/r/listusers.m
COPY prdimport.m /home/vehu/r/prdimport.m
COPY PXRMEXIU.m /home/vehu/r/PXRMEXIU.m
COPY PXRMEXIC.m /home/vehu/r/PXRMEXIC.m
COPY PXRMEXU4.m /home/vehu/r/PXRMEXU4.m
COPY setupnote.m /home/vehu/r/setupnote.m
COPY linkdlg.m /home/vehu/r/linkdlg.m
COPY fixdlgauth.m /home/vehu/r/fixdlgauth.m
COPY prd-files/ /prd-files/

# Fix line endings and set permissions
RUN sed -i 's/\r$//' /run.sh /patch_xusrb.py /import_prd.py /patch_gmtsobj.py /home/vehu/r/*.m && \
    chmod a+x /run.sh /patch_xusrb.py /import_prd.py /patch_gmtsobj.py

# SSH: enable password auth + install SSH key for passwordless access
RUN sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null; \
    sed -i 's/^#PasswordAuthentication/PasswordAuthentication/' /etc/ssh/sshd_config 2>/dev/null; \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config; \
    echo 'vehu:vehu' | chpasswd 2>/dev/null; \
    echo 'root:root' | chpasswd 2>/dev/null; \
    mkdir -p /root/.ssh /home/vehu/.ssh && \
    echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOJJKBmiXkEmIJjwuUK1M4hwjlv+NSHvq95HY0LWOCyu amcca@Cramer-PC' >> /root/.ssh/authorized_keys && \
    echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOJJKBmiXkEmIJjwuUK1M4hwjlv+NSHvq95HY0LWOCyu amcca@Cramer-PC' >> /home/vehu/.ssh/authorized_keys && \
    chmod 700 /root/.ssh /home/vehu/.ssh && \
    chmod 600 /root/.ssh/authorized_keys /home/vehu/.ssh/authorized_keys && \
    chown -R vehu:vehu /home/vehu/.ssh; \
    true

# Override entrypoint so our run.sh actually executes
ENTRYPOINT []

# Expose RPC Broker, web, SSH, YDB GUI
EXPOSE 9430 8001 22 8089

CMD ["/run.sh"]
