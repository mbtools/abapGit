CLASS lcl_checksum_serializer DEFINITION
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    CONSTANTS c_splitter TYPE string VALUE `|`.
    CONSTANTS c_root TYPE string VALUE `@`.

    CLASS-METHODS serialize
      IMPORTING
        it_checksums     TYPE zif_abapgit_persistence=>ty_local_checksum_tt
      RETURNING
        VALUE(rv_string) TYPE string.

    CLASS-METHODS deserialize
      IMPORTING
        iv_string           TYPE string
      RETURNING
        VALUE(rt_checksums) TYPE zif_abapgit_persistence=>ty_local_checksum_tt.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.

CLASS lcl_checksum_serializer IMPLEMENTATION.

  METHOD deserialize.

    DATA lt_buf_tab TYPE string_table.
    DATA lv_buf TYPE string.
    DATA lt_checksums LIKE rt_checksums.

    FIELD-SYMBOLS <ls_cs> LIKE LINE OF lt_checksums.
    FIELD-SYMBOLS <ls_file> LIKE LINE OF <ls_cs>-files.

    SPLIT iv_string AT |\n| INTO TABLE lt_buf_tab.

    LOOP AT lt_buf_tab INTO lv_buf.
      CHECK lv_buf IS NOT INITIAL. " In fact this is a bug ... it cannot be empty, maybe raise

      IF lv_buf+0(1) = '/'.
        IF <ls_cs> IS NOT ASSIGNED.
          " Incorrect checksums structure, maybe raise, though it is not critical for execution
          RETURN.
        ENDIF.

        APPEND INITIAL LINE TO <ls_cs>-files ASSIGNING <ls_file>.
        SPLIT lv_buf AT c_splitter INTO <ls_file>-path <ls_file>-filename <ls_file>-sha1.

        IF <ls_file>-path IS INITIAL OR <ls_file>-filename IS INITIAL OR <ls_file>-sha1 IS INITIAL.
          " Incorrect checksums structure, maybe raise, though it is not critical for execution
          RETURN.
        ENDIF.
      ELSEIF lv_buf = c_root. " Root
        APPEND INITIAL LINE TO lt_checksums ASSIGNING <ls_cs>. " Empty item
      ELSE.
        APPEND INITIAL LINE TO lt_checksums ASSIGNING <ls_cs>.
        SPLIT lv_buf AT c_splitter INTO <ls_cs>-item-obj_type <ls_cs>-item-obj_name <ls_cs>-item-devclass.

        IF <ls_cs>-item-obj_type IS INITIAL OR <ls_cs>-item-obj_name IS INITIAL OR <ls_cs>-item-devclass IS INITIAL.
          " Incorrect checksums structure, maybe raise, though it is not critical for execution
          RETURN.
        ENDIF.

      ENDIF.
    ENDLOOP.

    rt_checksums = lt_checksums.

  ENDMETHOD.

  METHOD serialize.

    DATA lt_buf_tab TYPE string_table.
    DATA lv_buf TYPE string.
    DATA lt_checksums_sorted TYPE zif_abapgit_persistence=>ty_local_checksum_by_item_tt.

    FIELD-SYMBOLS <ls_cs> LIKE LINE OF it_checksums.
    FIELD-SYMBOLS <ls_file> LIKE LINE OF <ls_cs>-files.

    lt_checksums_sorted = it_checksums.

    LOOP AT lt_checksums_sorted ASSIGNING <ls_cs>.

      IF lines( <ls_cs>-files ) = 0.
        CONTINUE.
      ENDIF.

      IF <ls_cs>-item-obj_type IS NOT INITIAL.
        CONCATENATE <ls_cs>-item-obj_type <ls_cs>-item-obj_name <ls_cs>-item-devclass
          INTO lv_buf
          SEPARATED BY c_splitter.
      ELSE.
        lv_buf = c_root.
      ENDIF.
      APPEND lv_buf TO lt_buf_tab.

      LOOP AT <ls_cs>-files ASSIGNING <ls_file>.

        CONCATENATE <ls_file>-path <ls_file>-filename <ls_file>-sha1
          INTO lv_buf
          SEPARATED BY c_splitter.
        APPEND lv_buf TO lt_buf_tab.

      ENDLOOP.

    ENDLOOP.

    rv_string = concat_lines_of(
      table = lt_buf_tab
      sep   = |\n| ).

  ENDMETHOD.
ENDCLASS.

**********************************************************************
* UPDATE CALCULATOR
**********************************************************************

CLASS lcl_update_calculator DEFINITION
  FINAL
  CREATE PUBLIC.
  PUBLIC SECTION.

    CLASS-METHODS calculate_updated
      IMPORTING
        it_updated_files     TYPE zif_abapgit_git_definitions=>ty_file_signatures_tt
        it_current_checksums TYPE zif_abapgit_persistence=>ty_local_checksum_tt
        it_local_files       TYPE zif_abapgit_definitions=>ty_files_item_tt
      RETURNING
        VALUE(rt_checksums)  TYPE zif_abapgit_persistence=>ty_local_checksum_tt.

  PRIVATE SECTION.

    CLASS-METHODS process_updated_files
      CHANGING
        ct_update_index TYPE zif_abapgit_git_definitions=>ty_file_signatures_ts
        ct_checksums    TYPE zif_abapgit_persistence=>ty_local_checksum_by_item_tt.

    CLASS-METHODS add_new_files
      IMPORTING
        it_local        TYPE zif_abapgit_definitions=>ty_files_item_tt
        it_update_index TYPE zif_abapgit_git_definitions=>ty_file_signatures_ts
      CHANGING
        ct_checksums    TYPE zif_abapgit_persistence=>ty_local_checksum_by_item_tt.

ENDCLASS.

CLASS lcl_update_calculator IMPLEMENTATION.

  METHOD calculate_updated.

    DATA lt_update_index TYPE zif_abapgit_git_definitions=>ty_file_signatures_ts.
    DATA lt_checksums_sorted TYPE zif_abapgit_persistence=>ty_local_checksum_by_item_tt.

    lt_checksums_sorted = it_current_checksums.
    lt_update_index     = it_updated_files.

    process_updated_files(
      CHANGING
        ct_update_index = lt_update_index
        ct_checksums    = lt_checksums_sorted ).

    add_new_files(
      EXPORTING
        it_update_index = lt_update_index
        it_local        = it_local_files
      CHANGING
        ct_checksums    = lt_checksums_sorted ).

    rt_checksums = lt_checksums_sorted.

  ENDMETHOD.

  METHOD process_updated_files.

    DATA lv_cs_row  TYPE i.
    DATA lv_file_row  TYPE i.

    FIELD-SYMBOLS <ls_checksum>  LIKE LINE OF ct_checksums.
    FIELD-SYMBOLS <ls_file>      LIKE LINE OF <ls_checksum>-files.
    FIELD-SYMBOLS <ls_new_state> LIKE LINE OF ct_update_index.

    " Loop through current checksum state, update sha1 for common files

    LOOP AT ct_checksums ASSIGNING <ls_checksum>.
      lv_cs_row = sy-tabix.

      LOOP AT <ls_checksum>-files ASSIGNING <ls_file>.
        lv_file_row = sy-tabix.

        READ TABLE ct_update_index ASSIGNING <ls_new_state>
          WITH KEY
            path     = <ls_file>-path
            filename = <ls_file>-filename.
        IF sy-subrc <> 0.
          CONTINUE. " Missing in updated files -> nothing to update, skip
        ENDIF.

        IF <ls_new_state>-sha1 IS INITIAL. " Empty input sha1 is a deletion marker
          DELETE <ls_checksum>-files INDEX lv_file_row.
        ELSE.
          <ls_file>-sha1 = <ls_new_state>-sha1.  " Update sha1
          CLEAR <ls_new_state>-sha1.             " Mark as processed
        ENDIF.
      ENDLOOP.

      IF lines( <ls_checksum>-files ) = 0. " Remove empty objects
        DELETE ct_checksums INDEX lv_cs_row.
      ENDIF.
    ENDLOOP.

    DELETE ct_update_index WHERE sha1 IS INITIAL. " Remove processed

  ENDMETHOD.

  METHOD add_new_files.

    DATA lt_local_sorted TYPE zif_abapgit_definitions=>ty_files_item_by_file_tt.
    DATA ls_checksum LIKE LINE OF ct_checksums.
    FIELD-SYMBOLS <ls_checksum> LIKE LINE OF ct_checksums.
    FIELD-SYMBOLS <ls_new_file> LIKE LINE OF it_update_index.
    FIELD-SYMBOLS <ls_local>    LIKE LINE OF lt_local_sorted.

    lt_local_sorted = it_local.

    " Add new files - not deleted and not marked as processed
    LOOP AT it_update_index ASSIGNING <ls_new_file>.

      READ TABLE lt_local_sorted ASSIGNING <ls_local>
        WITH KEY
          file-path     = <ls_new_file>-path
          file-filename = <ls_new_file>-filename.
      IF sy-subrc <> 0.
        " The file should be in locals, however:
        " if the deserialization fails, the local file might not be there
        " in this case no new CS added, and the file will appear to be remote+new
        CONTINUE.
      ENDIF.

      READ TABLE ct_checksums ASSIGNING <ls_checksum>
        WITH KEY
          item-obj_type = <ls_local>-item-obj_type
          item-obj_name = <ls_local>-item-obj_name.
      IF sy-subrc <> 0.
        MOVE-CORRESPONDING <ls_local>-item TO ls_checksum-item.
        INSERT ls_checksum INTO TABLE ct_checksums ASSIGNING <ls_checksum>.
      ENDIF.

      APPEND <ls_new_file> TO <ls_checksum>-files.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.


**********************************************************************
* FILTER
**********************************************************************

CLASS lcl_filter DEFINITION FINAL.
  PUBLIC SECTION.
    INTERFACES zif_abapgit_object_filter.

    METHODS constructor
      IMPORTING
        it_filter TYPE zif_abapgit_definitions=>ty_tadir_tt.

  PRIVATE SECTION.
    DATA mt_filter TYPE zif_abapgit_definitions=>ty_tadir_tt.
ENDCLASS.

CLASS lcl_filter IMPLEMENTATION.
  METHOD constructor.
    mt_filter = it_filter.
    SORT mt_filter.
    DELETE ADJACENT DUPLICATES FROM mt_filter.
  ENDMETHOD.

  METHOD zif_abapgit_object_filter~get_filter.
    rt_filter = mt_filter.
  ENDMETHOD.
ENDCLASS.

**********************************************************************
* CHECKSUM META
**********************************************************************

CLASS lcl_checksum_meta DEFINITION FINAL.
  PUBLIC SECTION.

    CLASS-METHODS add
      IMPORTING
        ii_repo    TYPE REF TO zif_abapgit_repo
        iv_text    TYPE string OPTIONAL
      CHANGING
        cv_cs_blob TYPE string
      RAISING
        zcx_abapgit_exception.

    CLASS-METHODS extract
      CHANGING
        cv_cs_blob TYPE string.

ENDCLASS.

CLASS lcl_checksum_meta IMPLEMENTATION.

  METHOD add.

    DATA lv_meta_str TYPE string.

    lv_meta_str = |#repo_name#{ ii_repo->get_name( ) }|.

    IF iv_text IS NOT INITIAL.
      lv_meta_str = |{ lv_meta_str } ({ iv_text })|.
    ENDIF.

    cv_cs_blob = lv_meta_str && |\n| && cv_cs_blob.

  ENDMETHOD.

  METHOD extract.

    DATA lv_meta_str TYPE string.

    IF cv_cs_blob IS INITIAL OR cv_cs_blob+0(1) <> '#'.
      RETURN. " No meta ? just ignore it
    ENDIF.

    SPLIT cv_cs_blob AT |\n| INTO lv_meta_str cv_cs_blob.
    " Just remove the header meta string - this is OK for now.
    " There is just repo name for the moment - needed to for DB util and potential debug

  ENDMETHOD.

ENDCLASS.

**********************************************************************
* CHECKSUM KEY
**********************************************************************

CLASS lcl_checksum_key DEFINITION FINAL.
  PUBLIC SECTION.

    CONSTANTS:
      c_new_checksums TYPE string VALUE 'CHECKSUM',
      c_max_repo_key  TYPE n LENGTH 5 VALUE '99999',
      c_max_db_key    TYPE n LENGTH 6 VALUE '999999'.

    TYPES:
      BEGIN OF ty_db_key,
        repo_key  TYPE n LENGTH 5,
        head_type TYPE c LENGTH 1,
        counter   TYPE n LENGTH 6,
      END OF ty_db_key,
      BEGIN OF ty_db_key_with_description,
        key    TYPE zif_abapgit_persistence=>ty_repo-key,
        text   TYPE string,
        is_new TYPE abap_bool,
      END OF ty_db_key_with_description,
      BEGIN OF ty_db_index,
        key      TYPE ty_db_key,
        settings TYPE zif_abapgit_persistence=>ty_remote_settings,
      END OF ty_db_index.

    CLASS-METHODS get
      IMPORTING
        iv_repo_key      TYPE zif_abapgit_persistence=>ty_repo-key
        ii_repo          TYPE REF TO zif_abapgit_repo
      RETURNING
        VALUE(rs_result) TYPE ty_db_key_with_description
      RAISING
        zcx_abapgit_exception.

  PRIVATE SECTION.

    CLASS-METHODS get_remote_settings
      IMPORTING
        ii_repo            TYPE REF TO zif_abapgit_repo
      RETURNING
        VALUE(rs_settings) TYPE zif_abapgit_persistence=>ty_remote_settings
      RAISING
        zcx_abapgit_exception.

    CLASS-METHODS get_key_with_description
      IMPORTING
        iv_repo_key      TYPE zif_abapgit_persistence=>ty_repo-key
        ii_repo          TYPE REF TO zif_abapgit_repo
        is_settings      TYPE zif_abapgit_persistence=>ty_remote_settings
      RETURNING
        VALUE(rs_result) TYPE ty_db_key_with_description
      RAISING
        zcx_abapgit_exception.

    CLASS-METHODS get_key
      IMPORTING
        iv_repo_key   TYPE zif_abapgit_persistence=>ty_repo-key
        iv_head_type  TYPE ty_db_key-head_type
        iv_counter    TYPE i DEFAULT 0
      RETURNING
        VALUE(rv_key) TYPE zif_abapgit_persistence=>ty_repo-key.

    CLASS-METHODS get_description
      IMPORTING
        is_settings    TYPE zif_abapgit_persistence=>ty_remote_settings
      RETURNING
        VALUE(rv_text) TYPE string.

    CLASS-METHODS index_to_settings
      IMPORTING
        iv_index         TYPE string
      RETURNING
        VALUE(rs_result) TYPE ty_db_index.

    CLASS-METHODS settings_to_index
      IMPORTING
        iv_key          TYPE zif_abapgit_persistence=>ty_repo-key
        is_settings     TYPE zif_abapgit_persistence=>ty_remote_settings
      RETURNING
        VALUE(rv_index) TYPE string.

    CLASS-METHODS migrate
      IMPORTING
        iv_repo_key TYPE zif_abapgit_persistence=>ty_repo-key
        iv_new_key  TYPE zif_abapgit_persistence=>ty_repo-key
        ii_repo     TYPE REF TO zif_abapgit_repo
        iv_text     TYPE string
      RAISING
        zcx_abapgit_exception.

ENDCLASS.

CLASS lcl_checksum_key IMPLEMENTATION.

  " The DB key is derived from the repo key and the remote head
  " nnnnnxiiiiii
  " n = repo key
  " x = head type (A=Index, B=Branch, T=Tag, C=Commit, P=Pull Request, F=Fork)
  " i = counter
  METHOD get.

    " TODO: Remove experimental feature switch
    IF zcl_abapgit_feature=>is_enabled( c_new_checksums ) IS INITIAL.
      rs_result-key = iv_repo_key.
      RETURN.
    ENDIF.

    " For offline repos, fallback to classic checksums
    IF ii_repo->is_offline( ) = abap_true.
      rs_result-key = iv_repo_key.
    ELSEIF iv_repo_key > c_max_repo_key.
      zcx_abapgit_exception=>raise( 'Too many repositories for new checksums' ).
    ELSE.
      rs_result = get_key_with_description(
        iv_repo_key = iv_repo_key
        ii_repo     = ii_repo
        is_settings = get_remote_settings( ii_repo ) ).
    ENDIF.

  ENDMETHOD.

  METHOD get_remote_settings.

    DATA li_repo_online TYPE REF TO zif_abapgit_repo_online.

    li_repo_online ?= ii_repo.
    rs_settings = li_repo_online->get_remote_settings( ).

    " Clear irrelevant settings
    CLEAR rs_settings-switched_origin.

    CASE rs_settings-head_type.
      WHEN zif_abapgit_git_definitions=>c_head_types-branch.
        CLEAR: rs_settings-tag, rs_settings-commit, rs_settings-pull_request, rs_settings-fork.
      WHEN zif_abapgit_git_definitions=>c_head_types-commit.
        CLEAR: rs_settings-branch, rs_settings-tag, rs_settings-pull_request, rs_settings-fork.
      WHEN zif_abapgit_git_definitions=>c_head_types-tag.
        CLEAR: rs_settings-branch, rs_settings-commit, rs_settings-pull_request, rs_settings-fork.
      WHEN zif_abapgit_git_definitions=>c_head_types-pull_request.
        CLEAR: rs_settings-branch, rs_settings-tag, rs_settings-commit, rs_settings-fork.
      WHEN zif_abapgit_git_definitions=>c_head_types-fork.
        CLEAR: rs_settings-branch, rs_settings-tag, rs_settings-commit, rs_settings-pull_request.
      WHEN OTHERS.
        ASSERT 0 = 1.
    ENDCASE.

  ENDMETHOD.

  METHOD get_key_with_description.

    DATA:
      lv_cs_blob    TYPE string,
      lv_cs_index   TYPE string,
      lt_cs_index   TYPE string_table,
      lv_db_index   TYPE zif_abapgit_persistence=>ty_repo-key,
      ls_db_index   TYPE ty_db_index,
      ls_db_key     TYPE ty_db_key,
      lv_db_counter TYPE i.

    " Get index of db keys
    lv_db_index = get_key(
      iv_repo_key  = iv_repo_key
      iv_head_type = zif_abapgit_git_definitions=>c_head_types-all ).

    TRY.
        lv_cs_blob = zcl_abapgit_persist_factory=>get_repo_cs( )->read( lv_db_index ).
      CATCH zcx_abapgit_exception zcx_abapgit_not_found ##NO_HANDLER.
    ENDTRY.

    lcl_checksum_meta=>extract( CHANGING cv_cs_blob = lv_cs_blob ).

    SPLIT lv_cs_blob AT |\n| INTO TABLE lt_cs_index.
    LOOP AT lt_cs_index INTO lv_cs_index.
      ls_db_index = index_to_settings( lv_cs_index ).

      " If the settings match, stop looking
      IF ls_db_index-settings = is_settings.
        rs_result-key  = ls_db_index-key.
        rs_result-text = get_description( ls_db_index-settings ).
        EXIT.
      ENDIF.

      " Get max counter
      ls_db_key = ls_db_index-key.
      IF ls_db_key-counter > lv_db_counter.
        lv_db_counter = ls_db_key-counter.
      ENDIF.
    ENDLOOP.

    " We found an existing key. Done!
    IF rs_result IS NOT INITIAL.
      RETURN.
    ENDIF.

    IF lv_db_counter >= c_max_db_key.
      zcx_abapgit_exception=>raise( 'Too many entries for new checksums' ).
    ENDIF.

    " Create a new db key with description
    lv_db_counter = lv_db_counter + 1.

    rs_result-key = get_key(
      iv_repo_key  = iv_repo_key
      iv_head_type = is_settings-head_type
      iv_counter   = lv_db_counter ).

    rs_result-text   = get_description( is_settings ).
    rs_result-is_new = abap_true.

    " Prepend new key (so most recent ones are fast to find) and save it in the index
    lv_cs_index = settings_to_index(
      iv_key      = rs_result-key
      is_settings = is_settings ).

    IF lv_cs_blob IS INITIAL.
      lv_cs_blob = lv_cs_index.
    ELSE.
      lv_cs_blob = lv_cs_index && |\n| && lv_cs_blob.
    ENDIF.

    lcl_checksum_meta=>add(
      EXPORTING
        ii_repo    = ii_repo
        iv_text    = 'Index'
      CHANGING
        cv_cs_blob = lv_cs_blob ).

    zcl_abapgit_persist_factory=>get_repo_cs( )->update(
      iv_key     = lv_db_index
      iv_cs_blob = lv_cs_blob ).

    " If this is the first time using new checksums for this repo,
    " clone old checksums (representing the current branch)
    " TODO: Move to zcl_abapgit_migrations
    IF lv_db_counter = 1.
      migrate(
        iv_repo_key = iv_repo_key
        iv_new_key  = rs_result-key
        ii_repo     = ii_repo
        iv_text     = rs_result-text ).
    ELSE.
      " rebuild
    ENDIF.

  ENDMETHOD.

  METHOD get_key.

    DATA ls_key TYPE ty_db_key.

    ls_key-repo_key  = iv_repo_key.
    ls_key-head_type = iv_head_type.
    ls_key-counter   = iv_counter.

    rv_key = ls_key.

  ENDMETHOD.

  METHOD get_description.

    DATA lv_pr TYPE string.
    DATA lv_fork TYPE string.

    CASE is_settings-head_type.
      WHEN zif_abapgit_git_definitions=>c_head_types-branch.
        rv_text = |Branch: { zcl_abapgit_git_branch_utils=>get_display_name( is_settings-branch ) }|.
      WHEN zif_abapgit_git_definitions=>c_head_types-commit.
        rv_text = |Commit: { is_settings-commit(7) }|.
      WHEN zif_abapgit_git_definitions=>c_head_types-tag.
        rv_text = |Tag: { zcl_abapgit_git_branch_utils=>get_display_name( is_settings-tag ) }|.
      WHEN zif_abapgit_git_definitions=>c_head_types-pull_request.
        " remove .git and domain to keep it short
        lv_pr = replace(
          val  = is_settings-pull_request
          sub  = '.git@'
          with = '@' ).
        lv_pr = replace(
          val   = lv_pr
          regex = 'https?://[^/]+/'
          with  = '' ).
        rv_text = |PR: { lv_pr }|.
      WHEN zif_abapgit_git_definitions=>c_head_types-fork.
        " remove .git and domain to keep it short
        lv_fork = replace(
          val  = is_settings-pull_request
          sub  = '.git#'
          with = '#' ).
        lv_fork = replace(
          val   = lv_fork
          regex = 'https?://[^/]+/'
          with  = '' ).
        rv_text = |Fork: { lv_fork }|.
      WHEN OTHERS.
        rv_text = ''.
    ENDCASE.

  ENDMETHOD.

  METHOD index_to_settings.

    SPLIT iv_index AT `|` INTO
      rs_result-key
      rs_result-settings-offline
      rs_result-settings-url
      rs_result-settings-branch
      rs_result-settings-tag
      rs_result-settings-commit
      rs_result-settings-pull_request
      rs_result-settings-head_type
      rs_result-settings-fork.

  ENDMETHOD.

  METHOD settings_to_index.

    rv_index = iv_key
      && '|' && is_settings-offline
      && '|' && is_settings-url
      && '|' && is_settings-branch
      && '|' && is_settings-tag
      && '|' && is_settings-commit
      && '|' && is_settings-pull_request
      && '|' && is_settings-head_type
      && '|' && is_settings-fork.

  ENDMETHOD.

  METHOD migrate.

    DATA lv_cs_blob TYPE string.

    " TODO: Make this a dedicated step in zcl_abapgit_migrations to process all repos
    TRY.
        lv_cs_blob = zcl_abapgit_persist_factory=>get_repo_cs( )->read( iv_repo_key ).
      CATCH zcx_abapgit_exception zcx_abapgit_not_found.
        RETURN.
    ENDTRY.

    lcl_checksum_meta=>extract( CHANGING cv_cs_blob = lv_cs_blob ).

    lcl_checksum_meta=>add(
      EXPORTING
        ii_repo    = ii_repo
        iv_text    = iv_text
      CHANGING
        cv_cs_blob = lv_cs_blob ).

    zcl_abapgit_persist_factory=>get_repo_cs( )->update(
      iv_key     = iv_new_key
      iv_cs_blob = lv_cs_blob ).

    " TODO: Drop old checksums
    " zcl_abapgit_persist_factory=>get_repo_cs( )->delete( iv_repo_key )

  ENDMETHOD.

ENDCLASS.
