#!/bin/sh

# This script creates a 32k fsLR version for the Brainnetome Child atlas.

# Set up the environment
FREESURFER_HOME=$1
TEMPLATEFLOW_HOME=$2
OUTPUT_DIR=$3
LEFT_ATLAS=$4
RIGHT_ATLAS=$5
SUBCORTICAL_ATLAS=$6

# Fetch path of the current script.
WDIR=$(dirname $(realpath $0))

# Set up the reference files
REFERENCE="${WDIR}/refs/fsaverage.BN_Atlas.32k_fs_LR.dlabel.nii"
REFERENCE_VOL="${WDIR}/refs/reference_subcortical_parcels.nii.gz"
REFERENCE_CIFTI="${WDIR}/refs/atlas-Tian_space-fsLR_den-32k_dseg.dlabel.nii"

# Set up the output directory
mkdir -p ${OUTPUT_DIR}
mkdir temp/

# Set freesurfer subjects path.
export FSAVERAGE=${FREESURFER_HOME}/subjects/fsaverage

# Create a subcortical segmentation containing the Brainnetome subcortical
# and cerbellum/brainstem regions from freesurfer's aseg.mgz.
mri_convert ${SUBCORTICAL_ATLAS} -nth 1 -voxsize 1 1 1 --resample_type nearest ${WDIR}/temp/subcortical.nii.gz 
mri_convert ${FSAVERAGE}/mri/aseg.mgz ${WDIR}/temp/aseg.nii.gz
scil_volume_math.py convert ${WDIR}/temp/aseg.nii.gz ${WDIR}/temp/aseg.nii.gz --data_type uint16 -f

# Fetching labels.
scil_labels_combine.py ${WDIR}/temp/brainstem_cerebellum.nii.gz --volume_ids ${WDIR}/temp/aseg.nii.gz 16 8 47 --out_labels_ids 225 226 227
scil_labels_combine.py ${WDIR}/temp/BN_child_subcortical.nii.gz --volume_ids ${WDIR}/temp/subcortical.nii.gz 211 212 213 214 215 216 217 \
    218 219 220 221 222 223 224 225 226 227 228 229 230 231 232 233 234 235 236 237 238 239 240 241 242 243 244 245 246 \
    --volume_ids ${WDIR}/temp/brainstem_cerebellum.nii.gz 225 226 227 \
    --out_labels_ids 189 190 191 192 193 194 195 196 197 198 199 200 201 202 203 204 205 206 207 208 209 210 211 212 213 \
    214 215 216 217 218 219 220 221 222 223 224 225 226 227

# Create a cifti header in the nifit file.
wb_command -volume-label-import ${WDIR}/temp/BN_child_subcortical.nii.gz ${WDIR}/refs/BN_child_parcel_labels.txt ${WDIR}/temp/BN_child_subcortical.nii -drop-unused-labels

# Resample into 32k space.
wb_command -volume-resample ${WDIR}/temp/BN_child_subcortical.nii ${REFERENCE_VOL} ENCLOSING_VOXEL ${WDIR}/temp/BN_child_subcortical_32k.nii

# Create the 164k version of the dense nifti files.
wb_command -cifti-create-label ${WDIR}/temp/atlas-BrainnetomeChild_space-fsLR_den-164k_dseg.dlabel.nii \
    -left-label ${LEFT_ATLAS} \
    -right-label ${RIGHT_ATLAS}

# Resample the 164k dense nifti files to 32k using fsaverage spheres.
wb_command -cifti-resample ${WDIR}/temp/atlas-BrainnetomeChild_space-fsLR_den-164k_dseg.dlabel.nii COLUMN \
    ${REFERENCE} COLUMN BARYCENTRIC ENCLOSING_VOXEL temp/atlas-BrainnetomeChild_space-fsLR_den-32k_dseg.dlabel.nii \
    -left-spheres ${TEMPLATEFLOW_HOME}/tpl-fsLR/tpl-fsLR_space-fsaverage_hemi-L_den-164k_sphere.surf.gii ${TEMPLATEFLOW_HOME}/tpl-fsLR/tpl-fsLR_space-fsaverage_hemi-L_den-32k_sphere.surf.gii \
    -right-spheres ${TEMPLATEFLOW_HOME}/tpl-fsLR/tpl-fsLR_space-fsaverage_hemi-R_den-164k_sphere.surf.gii ${TEMPLATEFLOW_HOME}/tpl-fsLR/tpl-fsLR_space-fsaverage_hemi-R_den-32k_sphere.surf.gii

# Add subcortical data by creating a dense cifti file from template.
wb_command -cifti-create-dense-from-template ${REFERENCE_CIFTI} \
    ${WDIR}/temp/atlas-BrainnetomeChild_space-fsLR_den-32k_dseg.dlabel.nii \
    -volume-all ${WDIR}/temp/BN_child_subcortical_32k.nii \
    -cifti ${WDIR}/temp/atlas-BrainnetomeChild_space-fsLR_den-32k_dseg.dlabel.nii

# Move files in output directory.
mv ${WDIR}/temp/atlas-BrainnetomeChild_space-fsLR_den-32k_dseg.dlabel.nii ${OUTPUT_DIR}/
cp ${WDIR}/refs/atlas-BrainnetomeChild_space-fsLR_den-32k_dseg.json ${OUTPUT_DIR}/
cp ${WDIR}/refs/atlas-BrainnetomeChild_dseg.tsv ${OUTPUT_DIR}/

# Clean up.
rm -rf ${WDIR}/temp/
