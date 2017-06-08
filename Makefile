FREEBSD_ROOT	:= $(abspath ./freebsd)
BHYVE_DIR		:= $(FREEBSD_ROOT)/usr.sbin/bhyve
BHYVE			:= $(BHYVE_DIR)/bhyve
BHYVELOAD_DIR	:= $(FREEBSD_ROOT)/usr.sbin/bhyveload/
BHYVELOAD		:= $(BHYVELOAD_DIR)/bhyveload
VMRUN			:= $(FREEBSD_ROOT)/share/examples/bhyve/vmrun.sh

LOG_FILE		:= /tmp/nvme_emu_log
#  DATE		:= $(shell date '+%Y%m%d_%H%M%S')
BACKUP_LOG_FILE	:= $(LOG_FILE).$(shell date '+%Y%m%d_%H%M%S')

DISK_IMAGE		:= $(abspath ./guest.img)

FREEBSD_VERSION	:= 11.0
ISO				:= FreeBSD-$(FREEBSD_VERSION)-RELEASE-amd64-bootonly.iso
ISO_FTP			:= ftp://ftp.freebsd.org/pub/FreeBSD/releases/ISO-IMAGES/$(FREEBSD_VERSION)/$(ISO)

VM_NAME			:= freebsd01

all: run

.IGNORE: $(BACKUP_LOG_FILE)
$(BACKUP_LOG_FILE):
	mv $(LOG_FILE) $@

$(ISO):
	fetch $(ISO_FTP)

$(DISK_IMAGE): $(ISO)
	truncate -s 16G $@
	sudo sh $(VMRUN) -c 2 -m 4G -t tap0 -d $@ -i -I $(ISO) $(VM_NAME)

.PHONY: bhyveload_build
bhyveload_build:
	make -C $(BHYVELOAD_DIR)

.PHONY:	bhyve_build
bhyve_build:
	make -C $(BHYVE_DIR)

.IGNORE: bhyve_stop
bhyve_stop:
	sudo bhyvectl --destroy --vm=$(VM_NAME)

.PHONY: run
run: $(BACKUP_LOG_FILE) bhyve_build bhyveload_build bhyve_stop $(DISK_IMAGE)
	sudo $(BHYVELOAD) -c stdio -m 4G -d $(DISK_IMAGE) $(VM_NAME)
	sudo $(BHYVE)	\
		-A 		\
		-H 		\
		-P 		\
		-c 1	\
		-m 4G 	\
		-l com1,stdio \
		-s 0:0,hostbridge \
		-s 1:0,lpc \
		-s 2:0,virtio-blk,$(DISK_IMAGE) \
		-s 3:0,virtio-net,tap0 \
		-s 4:0,nvme  \
		$(VM_NAME)

clean:
	make -C $(BHYVE_DIR) clean cleandepend
	make -C $(BHYVELOAD_DIR) clean cleandepend
