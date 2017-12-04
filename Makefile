FREEBSD_ROOT	:= $(abspath ./freebsd)
BHYVE_DIR		:= $(FREEBSD_ROOT)/usr.sbin/bhyve
BHYVE			:= $(BHYVE_DIR)/bhyve
BHYVELOAD_DIR	:= $(FREEBSD_ROOT)/usr.sbin/bhyveload/
BHYVELOAD		:= $(BHYVELOAD_DIR)/bhyveload
VMRUN			:= $(FREEBSD_ROOT)/share/examples/bhyve/vmrun.sh
DEBUGER 		:= gdb -tui --args

LOG_FILE		:= /tmp/nvme_emu_log
BACKUP_LOG_FILE	:= $(LOG_FILE).$(shell date '+%Y%m%d_%H%M%S')

DISK_IMAGE		:= $(abspath ./guest.img)

FREEBSD_VERSION	:= 11.0
ISO				:= FreeBSD-$(FREEBSD_VERSION)-RELEASE-amd64-bootonly.iso
ISO_FTP			:= ftp://ftp.freebsd.org/pub/FreeBSD/releases/ISO-IMAGES/$(FREEBSD_VERSION)/$(ISO)

VM_NAME			:= freebsd00

DEBUG			:= -g 8888
CPU_NUM			:= 1
MEM_SIZE		:= 4G
NVME_DISK		:= ./nvme.disk
	
all: help

.PHONY: help
help:
	@echo "list of subcommands"
	@echo "- bhyve_build"
	@echo "- bhyve_stop"
	@echo "- bhyveload_build"
	@echo "- run"
	@echo "- clean"
	@echo "- help"

.IGNORE: $(BACKUP_LOG_FILE)
$(BACKUP_LOG_FILE):
	mv $(LOG_FILE) $@

$(ISO):
	fetch $(ISO_FTP)

$(DISK_IMAGE): $(ISO)
	truncate -s 16G $@
	sudo sh $(VMRUN) -c 2 -m 4G -t tap0 -d $@ -i -I $(ISO) $(VM_NAME)

$(NVME_DISK): 
	truncate -s 16M $@

.PHONY: bhyveload_build
bhyveload_build:
	make -C $(BHYVELOAD_DIR)

.PHONY:	bhyve_build
bhyve_build:
	make -C $(BHYVE_DIR)

.IGNORE: bhyve_stop
bhyve_stop:
	sudo bhyvectl --destroy --vm=$(VM_NAME)

.PHONY: bootload
bootload: bhyve_build bhyveload_build $(DISK_IMAGE)

	sudo $(BHYVELOAD) -c stdio -m 4G -d $(DISK_IMAGE) $(VM_NAME)

.PHONY: run
run: bootload $(BACKUP_LOG_FILE) bhyve_build bhyveload_build $(DISK_IMAGE) $(NVME_DISK)
	sudo $(BHYVE)	\
		-A 		\
		-H 		\
		-P 		\
		-x 		\
		-c $(CPU_NUM)	\
		-m $(MEM_SIZE) \
		-l com1,stdio \
		-s 0:0,hostbridge \
		-s 1:0,lpc \
		-s 2:0,virtio-blk,$(DISK_IMAGE) \
		-s 3:0,virtio-net,tap0 \
        -s 4:0,nvme,$(NVME_DISK) \
		-g 8888 \
		$(VM_NAME)

#  debug: bootload


clean:
	make -C $(BHYVE_DIR) clean cleandepend
	make -C $(BHYVELOAD_DIR) clean cleandepend

netowrk:
	ifconfig tap0 create
	sysctl net.link.tap.up_on_open=1
	ifconfig bridge0 create
	ifconfig bridge0 addm re0 addm tap0
	ifconfig bridge0 up
