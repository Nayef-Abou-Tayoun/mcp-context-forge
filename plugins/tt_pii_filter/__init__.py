# -*- coding: utf-8 -*-
"""TT PII Filter Plugin - Custom TT Type detection.
Location: ./plugins/external/tt_pii_filter/__init__.py
Copyright 2025
SPDX-License-Identifier: Apache-2.0
Authors: Mihai Criveti

TT PII Filter Plugin with custom TT Type detection (e.g., s373-2312-r543).
External plugin loaded from Cloud Object Storage.
"""

from .tt_pii_filter import TTPIIFilterPlugin

__all__ = ["TTPIIFilterPlugin"]

# Made with Bob
