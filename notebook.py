import marimo

__generated_with = "0.25.0"
app = marimo.App(width="medium")


@app.cell
def _():
    import marimo as mo
    import pandas as pd
    import numpy as np


    return mo, np, pd


@app.cell
def _(mo):
    # Create an elegant input UI slider widget component to control data array boundaries
    slider = mo.ui.slider(start=10, stop=500, step=10, value=50, label="Mock Genomics Read Nodes")
    slider

    return (slider,)


@app.cell
def _(mo, np, pd, slider):
    # Referencing slider.value automatically links these cells together reactively
    n_points = slider.value

    data = pd.DataFrame({
        "Sequence Track ID": range(n_points),
        "Abundance Score": np.random.randint(5, 100, size=n_points)
    })

    # Output markdown text descriptions alongside data previews
    mo.md(f"""
    ### Live Data Stream
    Monitoring **{n_points}** synthetic track nodes inside your active `uv` path context.
    {mo.as_html(data.head())}
    """)

    return


if __name__ == "__main__":
    app.run()
