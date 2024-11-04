#### Creating the Brainnetome Child atlas as a BIDS dataset.

In order to process the functional resting-state data, it is required by `xcp_d` to provide the atlas in a BIDS-compliant format (following BIDS Extension Proposal 38). The current directory provides a bash script (`create_atlas_fsLR_32k.sh`) performing the conversion for the Brainnetome Child atlas $^1$. 

#### Requirements

Prior to creating the atlas, you will need to install the following libraries:

1. `scilpy` (https://github.com/scilus/scilpy.git)
2. `freesurfer` (https://surfer.nmr.mgh.harvard.edu/fswiki/DownloadAndInstall)
3. Connectome Workbench (https://www.humanconnectome.org/software/get-connectome-workbench)
4. `datalad` (https://www.datalad.org/#install)

> [!IMPORTANT]
> To convert the atlas from fsLR-164k to fsLR-32k, we need the `templateflow` $^2$ fsLR template. Assuming you already > installed datalad, you can fetch the required template using the following lines: 
> ```bash
> datalad install -r ///templateflow
> cd templateflow
> datalad get -r tpl-fsLR
> ```

You will also need both Brainnetome adult $^3$ (for subcortical segmentation) and Brainnetome child atlas files. The adult version can be downloaded from here: https://pan.cstcloud.cn/web/share.html?hash=DQov5gaAR4s. The child version can be accessed from here: https://www.scidb.cn/en/detail?dataSetId=74a20e6391b54ae8aac6e9c261b934d6.

#### How to use the bash script

The bash script can be called from the command line, assuming you have access to all dependencies (activate the `scilpy` python environment). Here are the required arguments:
```bash
bash create_atlas_fsLR_32k.sh <path/to/freesurfer/> <path/to/templateflow/> atlas-BrainnetomeChild refs/child_164k_L.label.gii refs/child_164k_R.label.gii refs/BN_Atlas_subcortex.gca
```

#### Inspect the results.
You can inspect the converted parcellation by opening the `atlas-BrainnetomeChild.scene` in the current directory using the `wb_view` command.

**References:** \
$^1$ Li, W., Fan, L., Shi, W., Lu, Y., Li, J., Luo, N., Wang, H., Chu, C., Ma, L., Song, M., Li, K., Cheng, L., Cao, L., & Jiang, T. (2023). Brainnetome atlas of preadolescent children based on anatomical connectivity profiles. Cerebral Cortex, 33(9), 5264–5275. https://doi.org/10.1093/cercor/bhac415 \
$^2$ TemplateFlow: a community archive of imaging templates and atlases for improved consistency in neuroimaging R Ciric, R Lorenz, WH Thompson, M Goncalves, E MacNicol, CJ Markiewicz, YO Halchenko, SS Ghosh, KJ Gorgolewski, RA Poldrack, O Esteban bioRxiv 2021.02.10.430678; https://doi.org/10.1101/2021.02.10.430678 \
$^3$ Fan, L., Li, H., Zhuo, J., Zhang, Y., Wang, J., Chen, L., Yang, Z., Chu, C., Xie, S., Laird, A. R., Fox, P. T., Eickhoff, S. B., Yu, C., & Jiang, T. (2016). The Human Brainnetome Atlas: A New Brain Atlas Based on Connectional Architecture. 19. https://doi.org/10.1093/cercor/bhw157

