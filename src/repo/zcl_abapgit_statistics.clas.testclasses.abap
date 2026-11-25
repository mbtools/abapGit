CLASS ltcl_statistics DEFINITION DEFERRED.
CLASS zcl_abapgit_statistics DEFINITION LOCAL FRIENDS ltcl_statistics.

CLASS lcl_repo DEFINITION FINAL INHERITING FROM zcl_abapgit_repo.
  PUBLIC SECTION.
    DATA mv_fail_tadir TYPE abap_bool.
    DATA mv_fail_serialize TYPE abap_bool.
    DATA mv_partial TYPE abap_bool.
    METHODS zif_abapgit_repo~get_tadir_objects REDEFINITION.
    METHODS zif_abapgit_repo~get_files_local REDEFINITION.
    METHODS zif_abapgit_repo~get_files_remote REDEFINITION.
ENDCLASS.

CLASS lcl_repo IMPLEMENTATION.
  METHOD zif_abapgit_repo~get_tadir_objects.
    DATA ls_tadir LIKE LINE OF rt_tadir.
    IF mv_fail_tadir = abap_true.
      zcx_abapgit_exception=>raise( 'TADIR failed' ).
    ENDIF.
    APPEND ls_tadir TO rt_tadir.
  ENDMETHOD.

  METHOD zif_abapgit_repo~get_files_local.
    DATA ls_file LIKE LINE OF rt_files.
    cl_abap_unit_assert=>assert_equals( act = iv_force
                                        exp = abap_true ).
    IF mv_fail_serialize = abap_true.
      zcx_abapgit_exception=>raise( 'Serialization failed' ).
    ENDIF.
    IF mv_partial = abap_true.
      ii_log->add_error( 'Object failed' ).
    ENDIF.
    ls_file-file-data = '0001FF'.
    APPEND ls_file TO rt_files.
    CLEAR ls_file.
    APPEND ls_file TO rt_files.
  ENDMETHOD.

  METHOD zif_abapgit_repo~get_files_remote.
    cl_abap_unit_assert=>fail( 'Statistics must not read remote files' ).
  ENDMETHOD.
ENDCLASS.

CLASS ltcl_statistics DEFINITION FINAL FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    DATA mo_repo TYPE REF TO lcl_repo.
    METHODS setup.
    METHODS local_counts FOR TESTING RAISING cx_static_check.
    METHODS online_url FOR TESTING RAISING cx_static_check.
    METHODS tadir_failure FOR TESTING RAISING cx_static_check.
    METHODS serialization_failure FOR TESTING RAISING cx_static_check.
    METHODS partial_serialization FOR TESTING RAISING cx_static_check.
    METHODS host_classification FOR TESTING.
    METHODS xml_roundtrip FOR TESTING RAISING cx_static_check.
ENDCLASS.

CLASS ltcl_statistics IMPLEMENTATION.
  METHOD setup.
    DATA ls_data TYPE zif_abapgit_persistence=>ty_repo.
    ls_data-key = '000000000001'.
    ls_data-package = '$STATISTICS'.
    ls_data-offline = abap_true.
    ls_data-local_settings-display_name = 'Test & repository'.
    ls_data-local_settings-write_protected = abap_true.
    CREATE OBJECT mo_repo EXPORTING is_data = ls_data.
  ENDMETHOD.

  METHOD local_counts.
    DATA ls_repo TYPE zcl_abapgit_statistics=>ty_repo.
    ls_repo = zcl_abapgit_statistics=>collect( ii_repo = mo_repo
                                               iv_favorite = abap_true ).
    cl_abap_unit_assert=>assert_equals( act = ls_repo-key
                                        exp = '000000000001' ).
    cl_abap_unit_assert=>assert_equals( act = ls_repo-objects
                                        exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_repo-files
                                        exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = ls_repo-size
                                        exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = ls_repo-favorite
                                        exp = abap_true ).
    cl_abap_unit_assert=>assert_equals( act = ls_repo-write_protected
                                        exp = abap_true ).
    cl_abap_unit_assert=>assert_initial( ls_repo-error ).
    cl_abap_unit_assert=>assert_initial( ls_repo-host ).
    cl_abap_unit_assert=>assert_initial( ls_repo-url ).
  ENDMETHOD.

  METHOD online_url.
    DATA ls_data TYPE zif_abapgit_persistence=>ty_repo.
    DATA ls_repo TYPE zcl_abapgit_statistics=>ty_repo.

    ls_data-package = '$STATISTICS'.
    ls_data-url = 'https://github.com/example/repository'.
    CREATE OBJECT mo_repo EXPORTING is_data = ls_data.
    ls_repo = zcl_abapgit_statistics=>collect( ii_repo = mo_repo
                                               iv_favorite = abap_false ).
    cl_abap_unit_assert=>assert_equals( act = ls_repo-url
      exp = ls_data-url ).
    cl_abap_unit_assert=>assert_equals( act = ls_repo-host
      exp = 'GitHub' ).
  ENDMETHOD.

  METHOD tadir_failure.
    DATA ls_repo TYPE zcl_abapgit_statistics=>ty_repo.
    mo_repo->mv_fail_tadir = abap_true.
    ls_repo = zcl_abapgit_statistics=>collect( ii_repo = mo_repo
                                               iv_favorite = abap_false ).
    cl_abap_unit_assert=>assert_equals( act = ls_repo-error
                                        exp = 'TADIR failed' ).
    cl_abap_unit_assert=>assert_equals( act = ls_repo-files
                                        exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = ls_repo-size
                                        exp = 3 ).
  ENDMETHOD.

  METHOD serialization_failure.
    DATA ls_repo TYPE zcl_abapgit_statistics=>ty_repo.
    mo_repo->mv_fail_serialize = abap_true.
    ls_repo = zcl_abapgit_statistics=>collect( ii_repo = mo_repo
                                               iv_favorite = abap_false ).
    cl_abap_unit_assert=>assert_equals( act = ls_repo-error
                                        exp = 'Serialization failed' ).
    cl_abap_unit_assert=>assert_equals( act = ls_repo-objects
                                        exp = 1 ).
    cl_abap_unit_assert=>assert_initial( ls_repo-files ).
  ENDMETHOD.

  METHOD partial_serialization.
    DATA ls_repo TYPE zcl_abapgit_statistics=>ty_repo.
    mo_repo->mv_partial = abap_true.
    ls_repo = zcl_abapgit_statistics=>collect( ii_repo = mo_repo
                                               iv_favorite = abap_false ).
    cl_abap_unit_assert=>assert_equals( act = ls_repo-error
                                        exp = 'Object failed' ).
    cl_abap_unit_assert=>assert_equals( act = ls_repo-files
                                        exp = 2 ).
  ENDMETHOD.

  METHOD host_classification.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_abapgit_statistics=>host( 'https://github.com/org/repo.git' )
      exp = 'GitHub' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_abapgit_statistics=>host( 'https://GitLab.com/org/repo' )
      exp = 'GitLab' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_abapgit_statistics=>host( 'https://example.com/github.com/repo' )
      exp = 'Others' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_abapgit_statistics=>host( 'https://github.com.example.com/org/repo' )
      exp = 'Others' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_abapgit_statistics=>host( 'invalid' )
      exp = 'Others' ).
  ENDMETHOD.

  METHOD xml_roundtrip.
    DATA ls_before TYPE zcl_abapgit_statistics=>ty_snapshot.
    DATA ls_after TYPE zcl_abapgit_statistics=>ty_snapshot.
    DATA ls_repo TYPE zcl_abapgit_statistics=>ty_repo.
    DATA li_output TYPE REF TO zif_abapgit_xml_output.
    DATA li_input TYPE REF TO zif_abapgit_xml_input.
    DATA lv_xml TYPE string.

    ls_before-refreshed_at = '20261123123456'.
    ls_repo = zcl_abapgit_statistics=>collect( ii_repo = mo_repo
                                               iv_favorite = abap_true ).
    ls_repo-size = '3000000000'. " Snapshots must support more than 2 GB
    ls_repo-url = 'https://github.com/example/repository'.
    APPEND ls_repo TO ls_before-repos.
    CREATE OBJECT li_output TYPE zcl_abapgit_xml_output.
    li_output->add( iv_name = 'STATISTICS'
                    ig_data = ls_before ).
    lv_xml = li_output->render( ).
    CREATE OBJECT li_input TYPE zcl_abapgit_xml_input EXPORTING iv_xml = lv_xml.
    li_input->read( EXPORTING iv_name = 'STATISTICS' CHANGING cg_data = ls_after ).
    cl_abap_unit_assert=>assert_equals( act = ls_after
                                        exp = ls_before ).
  ENDMETHOD.
ENDCLASS.
