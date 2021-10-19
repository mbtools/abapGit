CLASS zcl_abapgit_persist_injector DEFINITION
  PUBLIC
  CREATE PRIVATE
  FOR TESTING .

  PUBLIC SECTION.

    CLASS-METHODS set_repo
      IMPORTING
        !ii_repo TYPE REF TO zif_abapgit_persist_repo .

    CLASS-METHODS set_settings
      IMPORTING
        !ii_settings TYPE REF TO zif_abapgit_persist_settings .

    CLASS-METHODS set_user
      IMPORTING
        !ii_user TYPE REF TO zif_abapgit_persist_user .

  PROTECTED SECTION.
  PRIVATE SECTION.


ENDCLASS.



CLASS zcl_abapgit_persist_injector IMPLEMENTATION.


  METHOD set_repo.

    zcl_abapgit_persist_factory=>gi_repo = ii_repo.

  ENDMETHOD.


  METHOD set_settings.

    zcl_abapgit_persist_factory=>gi_settings = ii_settings.

  ENDMETHOD.


  METHOD set_user.

    zcl_abapgit_persist_factory=>gi_current_user = ii_user.

  ENDMETHOD.
ENDCLASS.
