#!/usr/bin/env python3
"""Classic plus one bounded, directed clock-load distribution step."""
from pathlib import Path
from librelane.flows import Flow
from librelane.flows.classic import Classic
from librelane.steps import Step
from librelane.steps.openroad import ResizerTimingPostCTS

@Step.factory.register()
class Stage12ClockSplit(ResizerTimingPostCTS):
    """Insert non-inverting clock buffers on groups of at most four CTS loads."""
    id = "OpenROAD.Stage12ClockSplit"
    name = "Stage 12 directed clock load distribution"

    def get_script_path(self):
        return str(Path(__file__).with_name("stage12_clock_split.tcl"))

@Flow.factory.register()
class Stage12ClockRepair(Classic):
    """Keep every Classic checker and insert a single step immediately after CTS."""
    Steps = []
    for original_step in Classic.Steps:
        Steps.append(original_step)
        if original_step.id == "OpenROAD.CTS":
            Steps.append(Stage12ClockSplit)

if __name__ == "__main__":
    from librelane.__main__ import cli
    cli()

