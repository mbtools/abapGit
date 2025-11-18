INTERFACE zif_abapgit_htmldiff
  PUBLIC.

************************************************************************
* ABAP HTML Diff
*
* This  is a port of JavaScript        (https://github.com/alaorneto/htmldiffer, no license)
* which is a port of CoffeeScript      (https://github.com/tnwinc/htmldiff.js, MIT license)
* which is a port of the original Ruby (https://github.com/myobie/htmldiff, MIT license)
*
* Copyright 2024 apm.to Inc. <https://apm.to>
* SPDX-License-Identifier: MIT
************************************************************************

  METHODS htmldiff
    IMPORTING
      !iv_before       TYPE string
      !iv_after        TYPE string
      !iv_with_img     TYPE abap_bool DEFAULT abap_false
    RETURNING
      VALUE(rv_result) TYPE string.

ENDINTERFACE.
