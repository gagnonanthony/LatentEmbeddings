#!/usr/bin/env python
# -*- coding: utf-8 -*-

import coloredlogs
import logging
import os

from cyclopts import App, Parameter
import json
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
    Extract DICE Score from JSON Files
    ----------------------------------
    This script extract DICE score from JSON files. Results will be outputted
    in a dataframe with single subject on each rows. JSON filename should
    contain the subject ID (e.g. sub-XXXXX__stats.json) at the beginning,
    followed by '__'.

    Parameters
    ----------
    in_directory : str
        The input directory containing the json files.
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

    # Get all the json files in the input directory
    logging.info(f"Reading JSON files from {in_directory}")
    json_files = [
        os.path.join(in_directory, f)
        for f in os.listdir(in_directory)
        if f.endswith(".json")
    ]

    # Initialize the dataframe
    df = pd.DataFrame()

    # Loop through all the json files to fetch the DICE score.
    logging.info("Processing JSON files...")
    for json_file in tqdm(json_files, desc="Processing JSON files"):
        with open(json_file, "r") as f:
            subid = os.path.basename(json_file).split("__")[0]
            data = json.load(f)
            dice = data["dice_voxels"]["1"][0]
            df = pd.concat(
                [
                    df,
                    pd.DataFrame(
                        {
                            "subjectkey": subid,
                            "DICE": dice,
                        },
                        index=[0],
                    ),
                ],
                axis=0
            )

    # Save the dataframe to the output file
    logging.info(f"Saving dataframe to {out_file}")
    df.to_csv(out_file, index=False, header=True)


if __name__ == "__main__":
    app()
