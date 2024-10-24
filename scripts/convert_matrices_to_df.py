#!/usr/bin/env python
# -*- coding: utf-8 -*-

import coloredlogs
import logging
import os

from cyclopts import App, Parameter
import numpy as np
import pandas as pd
from tqdm import tqdm
from typing_extensions import Annotated

from neurostatx.io.utils import assert_output

# Initializing the app.
app = App(default_parameter=Parameter(negative=()))


@app.default()
def main(
    in_directory: Annotated[
        str,
        Parameter(
            show_default=False,
            group="Essential Files Options",
        ),
    ],
    out_file: Annotated[
        str,
        Parameter(
            show_default=False,
            group="Essential Files Options",
        ),
    ],
    verbose: Annotated[
        bool,
        Parameter(
            "-v",
            "--verbose",
            group="Optional Parameters",
        ),
    ] = False,
    overwrite: Annotated[
        bool,
        Parameter(
            "-f",
            "--overwrite",
            group="Optional Parameters",
        ),
    ] = False,
):
    """
    Convert Matrices to Dataframes
    ------------------------------
    This script converts matrices to dataframes, meaning it extracts metrics
    for individual pair of ROIs. Input directory should be a directory
    containing a list of .npy files, each being a matrix. The output file
    should reflect the metric extracted. For example, if the input matrices
    are correlation matrices, the output file should reflect the correlation
    coefficient for each pair of ROIs. Matrices filename should contain the
    subject ID (e.g. sub-XXXXX__fa.npy) at the beginning, followed by '__'.

    Parameters
    ----------
    in_directory : str
        The input directory containing the matrices.
    out_file : str
        The output file to write the dataframe to.
    verbose : bool, optional
        Whether to show verbose logs.
    overwrite : bool, optional
        Whether to overwrite the output file if it already exists.
    """

    if verbose:
        logging.getLogger().setLevel(logging.INFO)
        coloredlogs.install(level=logging.INFO)

    assert_output(overwrite, out_file)

    logging.info("Loading matrices...")
    paths = os.listdir(in_directory)
    mat = np.load(os.path.join(in_directory, paths[0]))
    mask = np.ones([mat.shape[0], mat.shape[1]])

    logging.info("Setting up dataframe...")
    labels = pd.DataFrame(mask)
    labels_col = labels.columns
    labels_row = labels.index
    labels_value = labels.values
    labels_value = np.triu(labels_value)

    columns = []
    results = []
    subjects = []

    for i in range(labels_col.shape[0]):
        for j in range(labels_row.shape[0]):
            cond = labels_value[i, j]
            if cond == 1:
                columns.append(str(int(labels_col[i] + 1)) + "_" +
                               str(int(labels_row[j] + 1)))

    logging.info("Converting...")
    for path in tqdm(paths):
        sub_id = path.split("__")[0]
        subjects.append(sub_id)
        mat = np.triu(np.load(os.path.join(in_directory, path)))
        output = []
        for i in range(labels_col.shape[0]):
            for j in range(labels_row.shape[0]):
                cond = labels_value[i, j]
                if cond == 1:
                    output.append(mat[i, j])
        results.append([x for x in output])

    final = pd.DataFrame(results, columns=columns)
    final.index = subjects

    logging.info("Writing to file...")
    final.to_csv(out_file, header=True, index=True, index_label="subjectkey")


if __name__ == "__main__":
    app()
