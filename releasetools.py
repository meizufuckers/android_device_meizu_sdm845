#
# Copyright (C) 2009 The Android Open Source Project
# Copyright (c) 2011-2013, 2020 The Linux Foundation.
# Copyright (C) 2023 transaero21 <transaero21@elseboot.ru>
#
# SPDX-License-Identifier: Apache-2.0
#

"""Emit commands needed for QCOM devices during OTA installation
(installing the radio image)."""

import common
import os
import re


bootImages = {}
binImages = {}
fwImages = {}

# List of images that we pick from IMAGES/ in target-files.
target_files_IMAGES_list = [] # Empty

# The joined list of user image partitions of source and target builds.
# - Items should be added to the list if new dynamic partitions are added.
# - Items should not be removed from the list even if dynamic partitions are
#   deleted. When generating an incremental OTA package, this script needs to
#   know that an image is present in source build but not in target build.
USERIMAGE_PARTITIONS = [] # Empty

# Parse filesmap file containing firmware residing places
def LoadFilesMap(zip, name="RADIO/filesmap"):
  try:
    data = zip.read(name).decode()
  except KeyError:
    print("Warning: could not find %s in %s." % (name, zip))
    data = ""
  d = {}
  for line in data.splitlines():
    line = line.strip()
    if not line or line.startswith("#"):
      continue
    pieces = line.split()
    if not (len(pieces) == 2):
      raise ValueError("malformed filesmap line: \"%s\"" % (line))
    d[pieces[0]] = pieces[1]
  return d


# Read firmware images from target files zip
def GetRadioFiles(z):
  out = {}
  for info in z.infolist():
    f = info.filename
    if f.startswith("RADIO/") and (f.__len__() > len("RADIO/")):
      fn = f[6:]
      if fn.startswith("filesmap"):
        continue
      data = z.read(f)
      out[fn] = common.File(f, data)

    # This is to include vbmeta,dtbo images from IMAGES/ folder.
    if f.startswith("IMAGES/") and (f.__len__() > len("IMAGES/")):
      fn = f[7:]
      if (fn in target_files_IMAGES_list):
        data = z.read(f)
        out[fn] = common.File(f, data)

  return out


# Get firmware residing place from filesmap
def GetFileDestination(fn, filesmap):
  # if file is encoded disregard the .enc extention
  if fn.endswith('.enc'):
    fn = fn[:-4]

  # get backup destination as well if present
  backup = None
  if fn + ".bak" in filesmap:
    backup = filesmap[fn + ".bak"]

  # Assert if an image belonging to target_files_IMAGES_list is not found in filesmap
  # but found in IMAGES/ as these are critical images like vbmeta/dtbo etc.
  if fn in target_files_IMAGES_list and fn not in filesmap:
    raise common.ExternalError("Filesmap entry for "+ fn +" missing !!")

  # If full filename is not specified in filesmap get only the name part
  # and look for this token
  if fn not in filesmap:
    fn = fn.split(".")[0] + ".*"
    if fn not in filesmap:
      print("warning radio-update: '%s' not found in filesmap" % (fn))
      return None, backup
  return filesmap[fn], backup


# Separate image types as each type needs different handling
def SplitFwTypes(files):
  boot = {}
  bin = {}
  fw = {}

  for f in files:
    extIdx = -1
    dotSeparated = f.split(".")
    while True:
      if dotSeparated[extIdx] != 'p' and dotSeparated[extIdx] != 'enc':
        break
      extIdx -= 1

    if dotSeparated[extIdx] == 'mbn' or dotSeparated[extIdx] == 'elf' or  dotSeparated[extIdx] == 'img':
      boot[f] = files[f]
    elif dotSeparated[extIdx] == 'bin':
      bin[f] = files[f]
    else:
      fw[f] = files[f]
  return boot, bin, fw


# Prepare radio-update files and verify them
def OTA_VerifyEnd(info, api_version, target_zip, source_zip=None):
  if api_version < 3:
    print("warning radio-update: no support for api_version less than 3")
    return False

  print("Loading radio filesmap...")
  filesmap = LoadFilesMap(target_zip)
  if filesmap == {}:
    print("warning radio-update: no or invalid filesmap file found")
    return False

  print("Loading radio target...")
  tgt_files = GetRadioFiles(target_zip)
  if tgt_files == {}:
    print("warning radio-update: no radio images in input target_files")
    return False

  src_files = None
  if source_zip is not None:
    print("Loading radio source...")
    src_files = GetRadioFiles(source_zip)

  update_list = {}
  largest_source_size = 0

  print("Preparing radio-update files...")
  for fn in tgt_files:
    dest, destBak = GetFileDestination(fn, filesmap)
    if dest is None:
      continue

    tf = tgt_files[fn]
    sf = None
    if src_files is not None:
      sf = src_files.get(fn, None)

    full = sf is None or fn.endswith('.enc')
    if not full:
      # no difference - skip this file
      if tf.sha1 == sf.sha1:
        continue
      d = common.Difference(tf, sf)
      _, _, d = d.ComputePatch()
      # no difference - skip this file
      if d is None:
        continue
      # if patch is almost as big as the file - don't bother patching
      full = len(d) > tf.size * common.OPTIONS.patch_threshold
      if not full:
        f = "patch/firmware-update/" + fn + ".p"
        common.ZipWriteStr(info.output_zip, f, d)
        update_list[f] = (dest, destBak, tf, sf)
        largest_source_size = max(largest_source_size, sf.size)
    if full:
      f = "firmware-update/" + fn
      common.ZipWriteStr(info.output_zip, f, tf.data)
      update_list[f] = (dest, destBak, None, None)

  global bootImages
  global binImages
  global fwImages
  bootImages, binImages, fwImages = SplitFwTypes(update_list)

  # If there are incremental patches verify them
  if largest_source_size != 0:
    info.script.Comment("---- radio update verification ----")
    info.script.Print("Verifying radio-update...")

    for f in bootImages:
      dest, destBak, tf, sf = bootImages[f]
      # Not incremental
      if sf is None:
        continue
      info.script.PatchCheck("EMMC:%s:%d:%s:%d:%s" %
              (dest, sf.size, sf.sha1, tf.size, tf.sha1))
      if destBak is not None:
        info.script.PatchCheck("EMMC:%s:%d:%s:%d:%s" %
                (destBak, sf.size, sf.sha1, tf.size, tf.sha1))
    for f in binImages:
      dest, destBak, tf, sf = binImages[f]
      # Not incremental
      if sf is None:
        continue
      info.script.PatchCheck("EMMC:%s:%d:%s:%d:%s" %
              (dest, sf.size, sf.sha1, tf.size, tf.sha1))

    last_mounted = ""
    for f in fwImages:
      dest, destBak, tf, sf = fwImages[f]
      # Not incremental
      if sf is None:
        continue
      # Get the filename without the path and the patch (.p) extention
      f = f.split("/")[-1][:-2]
      # Parse filesmap destination paths for "/dev/" pattern in the beginng.
      # This would mean that the file must be written to block device -
      # fs mount needed
      if dest.startswith("/dev/"):
        if last_mounted != dest:
          info.script.AppendExtra('unmount("/firmware");')
          info.script.AppendExtra('mount("vfat", "EMMC", "%s", "/firmware");' %
                                    (dest))
          last_mounted = dest
        dest = "/firmware/image/" + f
      else:
        dest = dest + "/" + f
      info.script.PatchCheck(dest, tf.sha1, sf.sha1)

    info.script.CacheFreeSpaceCheck(largest_source_size)
  return True


def FullOTA_InstallBegin(info):
  AddMeizuClearRoot(info.script)
  return


def IncrementalOTA_InstallBegin(info):
  AddMeizuClearRoot(info.script)
  return


def AddMeizuClearRoot(script):
  script.AppendExtra('ifelse(meizu.get_root_state(), meizu.clear_root(), "");')
  return

def IncrementalOTA_VerifyEnd(info):
 OTA_VerifyEnd(info, info.target_version, info.target_zip, info.source_zip)
 return


# This function handles only non-HLOS whole partition images
def InstallRawImage(script, f, dest, tf, sf):
  if f.endswith('.p'):
    script.ApplyPatch("EMMC:%s:%d:%s:%d:%s" %
                        (dest, sf.size, sf.sha1, tf.size, tf.sha1),
                        "-", tf.size, tf.sha1, sf.sha1, f)
  elif f.endswith('.enc'):
    # Get the filename without the path
    fn = f.split("/")[-1]
    script.AppendExtra('package_extract_file("%s", "/tmp/%s");' % (f, fn))
    script.AppendExtra('msm.decrypt("/tmp/%s", "%s");' % (fn, dest))
  else:
    script.AppendExtra('package_extract_file("%s", "%s");' % (f, dest))
  return


# This function handles only non-HLOS boot images - files list must contain
# only such images (aboot, tz, etc)
def InstallBootImages(script, files):
  bakExists = False
  # update main partitions
  script.AppendExtra('ifelse(msm.boot_update("main"), (')
  for f in files:
    dest, destBak, tf, sf = files[f]
    if destBak is not None:
      bakExists = True
    InstallRawImage(script, f, dest, tf, sf)
  script.AppendExtra('), "");')

  # update backup partitions
  if bakExists:
    script.AppendExtra('ifelse(msm.boot_update("backup"), (')
    for f in files:
      dest, destBak, tf, sf = files[f]
      if destBak is not None:
        InstallRawImage(script, f, destBak, tf, sf)
    script.AppendExtra('), "");')
  # just finalize primary update stage
  else:
    script.AppendExtra('msm.boot_update("backup");')

  # finalize partitions update
  script.AppendExtra('msm.boot_update("finalize");')
  return


# This function handles only non-HLOS bin images
def InstallBinImages(script, files):
  for f in files:
    dest, _, tf, sf = files[f]
    InstallRawImage(script, f, dest, tf, sf)
  return


# This function handles only non-HLOS firmware files that are not whole
# partition images (modem, dsp, etc)
def InstallFwImages(script, files):
  last_mounted = ""

  for f in files:
    dest, _, tf, sf = files[f]
    # Get the filename without the path
    fn = f.split("/")[-1]
    # Parse filesmap destination paths for "/dev/" pattern in the beginng.
    # This would mean that the file must be written to block device -
    # fs mount needed
    if dest.startswith("/dev/"):
      if last_mounted != dest:
        script.AppendExtra('unmount("/firmware");')
        script.AppendExtra('mount("vfat", "EMMC", "%s", "/firmware");' %
                            (dest))
        last_mounted = dest
      dest = "/firmware/image/" + fn
    else:
      dest = dest + "/" + fn

    if f.endswith('.p'):
      script.ApplyPatch(dest[:-2], "-", tf.size, tf.sha1, sf.sha1, f)
    elif f.endswith('.enc'):
      script.AppendExtra('package_extract_file("%s", "/tmp/%s");' % (f, fn))
      script.AppendExtra('msm.decrypt("/tmp/%s", "%s");' % (fn, dest[:-4]))
    else:
      script.AppendExtra('package_extract_file("%s", "%s");' % (f, dest))

  if last_mounted != "":
    script.AppendExtra('unmount("/firmware");')
  return


def OTA_InstallEnd(info):
  print("Applying radio-update script modifications...")
  info.script.Comment("---- radio update tasks ----")
  info.script.Print("Patching firmware images...")

  if bootImages != {}:
    InstallBootImages(info.script, bootImages)
  if binImages != {}:
    InstallBinImages(info.script, binImages)
  if fwImages != {}:
    InstallFwImages(info.script, fwImages)
  return


def FullOTA_InstallEnd_MMC(info):
  if OTA_VerifyEnd(info, info.input_version, info.input_zip):
    OTA_InstallEnd(info)
  return


def FullOTA_InstallEnd_MTD(info):
  print("warning radio-update: radio update for NAND devices not supported")
  return


def FullOTA_InstallEnd(info):
  FullOTA_InstallEnd_MMC(info)
  return

def IncrementalOTA_InstallEnd_MMC(info):
  OTA_InstallEnd(info)
  return


def IncrementalOTA_InstallEnd_MTD(info):
  print("warning radio-update: radio update for NAND devices not supported")
  return

def IncrementalOTA_InstallEnd(info):
  IncrementalOTA_InstallEnd_MMC(info)
  return

def GetUserImages(input_tmp, input_zip):
  return {partition: common.GetUserImage(partition, input_tmp, input_zip)
          for partition in USERIMAGE_PARTITIONS
          if os.path.exists(os.path.join(input_tmp,
                                         "IMAGES", partition + ".img"))}

def FullOTA_GetBlockDifferences(info):
  images = GetUserImages(info.input_tmp, info.input_zip)
  return [common.BlockDifference(partition, image)
          for partition, image in images.items()]

def IncrementalOTA_GetBlockDifferences(info):
  source_images = GetUserImages(info.source_tmp, info.source_zip)
  target_images = GetUserImages(info.target_tmp, info.target_zip)

  # Use EmptyImage() as a placeholder for partitions that will be deleted.
  for partition in source_images:
    target_images.setdefault(partition, common.EmptyImage())

  # Use source_images.get() because new partitions are not in source_images.
  return [common.BlockDifference(partition, target_image, source_images.get(partition))
          for partition, target_image in target_images.items()]
