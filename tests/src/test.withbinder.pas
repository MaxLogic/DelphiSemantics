unit Test.WithBinder;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Api, DelphiSemantics.Api.RemoveWith,
  DelphiSemantics.Api.RemoveWith.Compatibility,
  DelphiSemantics.Model, DelphiSemantics.RootMemberAbsence, DelphiSemantics.WithBinding;

type
  [TestFixture]
  TWithBinderTests = class
  private
    function LoadModel: TDelphiSemanticUnitModel;
    function LoadBareReceiverSafetyModels: TArray<TDelphiSemanticUnitModel>;
    function LoadReceiverSafetyModels: TArray<TDelphiSemanticUnitModel>;
    function HasReference(const aBinding: TDelphiSemanticWithBinding; const aName,
      aClassification: string): Boolean;
    function HasAnyReference(const aBinding: TDelphiSemanticWithBinding; const aName: string):
      Boolean;
    function ReceiverOf(const aBinding: TDelphiSemanticWithBinding; const aName,
      aClassification: string): string;
    function CountReferences(const aBinding: TDelphiSemanticWithBinding; const aName: string):
      Integer;
    function LookupSourceOf(const aBinding: TDelphiSemanticWithBinding; const aName,
      aClassification: string): string;
    function ReasonOf(const aBinding: TDelphiSemanticWithBinding; const aName,
      aClassification: string): string;
    function HasInventorySymbol(const aInventory: TDelphiSemanticRemoveWithInventory;
      const aName, aSymbolClass, aRoutineName: string): Boolean;
    function TryFindInventorySymbol(const aInventory: TDelphiSemanticRemoveWithInventory;
      const aName, aSymbolClass, aOwnerName: string; out aSymbol:
      TDelphiSemanticInventorySymbol): Boolean;
  public
    [TestCase('comp-tag-read cold', 'comp-tag-read,cold')]
    [TestCase('comp-tag-read snapshot', 'comp-tag-read,snapshot')]
    [TestCase('comp-tag-read sessioncold', 'comp-tag-read,sessioncold')]
    [TestCase('comp-tag-read sessionwarm', 'comp-tag-read,sessionwarm')]
    [TestCase('comp-tag-read standalone', 'comp-tag-read,standalone')]
    [TestCase('comp-tag-read rootcold', 'comp-tag-read,rootcold')]
    [TestCase('comp-tag-write cold', 'comp-tag-write,cold')]
    [TestCase('comp-tag-write snapshot', 'comp-tag-write,snapshot')]
    [TestCase('comp-tag-write sessioncold', 'comp-tag-write,sessioncold')]
    [TestCase('comp-tag-write sessionwarm', 'comp-tag-write,sessionwarm')]
    [TestCase('comp-tag-write standalone', 'comp-tag-write,standalone')]
    [TestCase('comp-tag-write rootcold', 'comp-tag-write,rootcold')]
    [TestCase('comp-name-read cold', 'comp-name-read,cold')]
    [TestCase('comp-name-read snapshot', 'comp-name-read,snapshot')]
    [TestCase('comp-name-read sessioncold', 'comp-name-read,sessioncold')]
    [TestCase('comp-name-read sessionwarm', 'comp-name-read,sessionwarm')]
    [TestCase('comp-name-read standalone', 'comp-name-read,standalone')]
    [TestCase('comp-name-read rootcold', 'comp-name-read,rootcold')]
    [TestCase('comp-owner-read cold', 'comp-owner-read,cold')]
    [TestCase('comp-owner-read snapshot', 'comp-owner-read,snapshot')]
    [TestCase('comp-owner-read sessioncold', 'comp-owner-read,sessioncold')]
    [TestCase('comp-owner-read sessionwarm', 'comp-owner-read,sessionwarm')]
    [TestCase('comp-owner-read standalone', 'comp-owner-read,standalone')]
    [TestCase('comp-owner-read rootcold', 'comp-owner-read,rootcold')]
    [TestCase('comp-tag-noglobal cold', 'comp-tag-noglobal,cold')]
    [TestCase('comp-tag-noglobal snapshot', 'comp-tag-noglobal,snapshot')]
    [TestCase('comp-tag-noglobal sessioncold', 'comp-tag-noglobal,sessioncold')]
    [TestCase('comp-tag-noglobal sessionwarm', 'comp-tag-noglobal,sessionwarm')]
    [TestCase('comp-tag-noglobal standalone', 'comp-tag-noglobal,standalone')]
    [TestCase('comp-tag-noglobal rootcold', 'comp-tag-noglobal,rootcold')]
    [TestCase('comp-2level-tag cold', 'comp-2level-tag,cold')]
    [TestCase('comp-2level-tag snapshot', 'comp-2level-tag,snapshot')]
    [TestCase('comp-2level-tag sessioncold', 'comp-2level-tag,sessioncold')]
    [TestCase('comp-2level-tag sessionwarm', 'comp-2level-tag,sessionwarm')]
    [TestCase('comp-2level-tag standalone', 'comp-2level-tag,standalone')]
    [TestCase('comp-2level-tag rootcold', 'comp-2level-tag,rootcold')]
    [TestCase('comp-method-call cold', 'comp-method-call,cold')]
    [TestCase('comp-method-call snapshot', 'comp-method-call,snapshot')]
    [TestCase('comp-method-call sessioncold', 'comp-method-call,sessioncold')]
    [TestCase('comp-method-call sessionwarm', 'comp-method-call,sessionwarm')]
    [TestCase('comp-method-call standalone', 'comp-method-call,standalone')]
    [TestCase('comp-method-call rootcold', 'comp-method-call,rootcold')]
    [TestCase('intf-refcount cold', 'intf-refcount,cold')]
    [TestCase('intf-refcount snapshot', 'intf-refcount,snapshot')]
    [TestCase('intf-refcount sessioncold', 'intf-refcount,sessioncold')]
    [TestCase('intf-refcount sessionwarm', 'intf-refcount,sessionwarm')]
    [TestCase('intf-refcount standalone', 'intf-refcount,standalone')]
    [TestCase('intf-refcount rootcold', 'intf-refcount,rootcold')]
    [TestCase('obj-classname-implicit cold', 'obj-classname-implicit,cold')]
    [TestCase('obj-classname-implicit snapshot', 'obj-classname-implicit,snapshot')]
    [TestCase('obj-classname-implicit sessioncold', 'obj-classname-implicit,sessioncold')]
    [TestCase('obj-classname-implicit sessionwarm', 'obj-classname-implicit,sessionwarm')]
    [TestCase('obj-classname-implicit standalone', 'obj-classname-implicit,standalone')]
    [TestCase('obj-classname-implicit rootcold', 'obj-classname-implicit,rootcold')]
    [TestCase('obj-classname-explicit cold', 'obj-classname-explicit,cold')]
    [TestCase('obj-classname-explicit snapshot', 'obj-classname-explicit,snapshot')]
    [TestCase('obj-classname-explicit sessioncold', 'obj-classname-explicit,sessioncold')]
    [TestCase('obj-classname-explicit sessionwarm', 'obj-classname-explicit,sessionwarm')]
    [TestCase('obj-classname-explicit standalone', 'obj-classname-explicit,standalone')]
    [TestCase('obj-classname-explicit rootcold', 'obj-classname-explicit,rootcold')]
    [TestCase('anc-weak-alias-tag cold', 'anc-weak-alias-tag,cold')]
    [TestCase('anc-weak-alias-tag snapshot', 'anc-weak-alias-tag,snapshot')]
    [TestCase('anc-weak-alias-tag sessioncold', 'anc-weak-alias-tag,sessioncold')]
    [TestCase('anc-weak-alias-tag sessionwarm', 'anc-weak-alias-tag,sessionwarm')]
    [TestCase('anc-weak-alias-tag standalone', 'anc-weak-alias-tag,standalone')]
    [TestCase('anc-weak-alias-tag rootcold', 'anc-weak-alias-tag,rootcold')]
    [TestCase('anc-strong-alias-tag cold', 'anc-strong-alias-tag,cold')]
    [TestCase('anc-strong-alias-tag snapshot', 'anc-strong-alias-tag,snapshot')]
    [TestCase('anc-strong-alias-tag sessioncold', 'anc-strong-alias-tag,sessioncold')]
    [TestCase('anc-strong-alias-tag sessionwarm', 'anc-strong-alias-tag,sessionwarm')]
    [TestCase('anc-strong-alias-tag standalone', 'anc-strong-alias-tag,standalone')]
    [TestCase('anc-strong-alias-tag rootcold', 'anc-strong-alias-tag,rootcold')]
    [TestCase('nested-outerrec-has-tag cold', 'nested-outerrec-has-tag,cold')]
    [TestCase('nested-outerrec-has-tag snapshot', 'nested-outerrec-has-tag,snapshot')]
    [TestCase('nested-outerrec-has-tag sessioncold', 'nested-outerrec-has-tag,sessioncold')]
    [TestCase('nested-outerrec-has-tag sessionwarm', 'nested-outerrec-has-tag,sessionwarm')]
    [TestCase('nested-outerrec-has-tag standalone', 'nested-outerrec-has-tag,standalone')]
    [TestCase('nested-outerrec-has-tag rootcold', 'nested-outerrec-has-tag,rootcold')]
    [TestCase('comp-in-method cold', 'comp-in-method,cold')]
    [TestCase('comp-in-method snapshot', 'comp-in-method,snapshot')]
    [TestCase('comp-in-method sessioncold', 'comp-in-method,sessioncold')]
    [TestCase('comp-in-method sessionwarm', 'comp-in-method,sessionwarm')]
    [TestCase('comp-in-method standalone', 'comp-in-method,standalone')]
    [TestCase('comp-in-method rootcold', 'comp-in-method,rootcold')]
    [TestCase('alias-projclass-classname cold', 'alias-projclass-classname,cold')]
    [TestCase('alias-projclass-classname snapshot', 'alias-projclass-classname,snapshot')]
    [TestCase('alias-projclass-classname sessioncold', 'alias-projclass-classname,sessioncold')]
    [TestCase('alias-projclass-classname sessionwarm', 'alias-projclass-classname,sessionwarm')]
    [TestCase('alias-projclass-classname standalone', 'alias-projclass-classname,standalone')]
    [TestCase('alias-projclass-classname rootcold', 'alias-projclass-classname,rootcold')]
    [TestCase('sr-excludeattr cold', 'sr-excludeattr,cold')]
    [TestCase('sr-excludeattr snapshot', 'sr-excludeattr,snapshot')]
    [TestCase('sr-excludeattr sessioncold', 'sr-excludeattr,sessioncold')]
    [TestCase('sr-excludeattr sessionwarm', 'sr-excludeattr,sessionwarm')]
    [TestCase('sr-excludeattr standalone', 'sr-excludeattr,standalone')]
    [TestCase('sr-excludeattr rootcold', 'sr-excludeattr,rootcold')]
    [TestCase('sr-findhandle cold', 'sr-findhandle,cold')]
    [TestCase('sr-findhandle snapshot', 'sr-findhandle,snapshot')]
    [TestCase('sr-findhandle sessioncold', 'sr-findhandle,sessioncold')]
    [TestCase('sr-findhandle sessionwarm', 'sr-findhandle,sessionwarm')]
    [TestCase('sr-findhandle standalone', 'sr-findhandle,standalone')]
    [TestCase('sr-findhandle rootcold', 'sr-findhandle,rootcold')]
    [TestCase('sr-finddata cold', 'sr-finddata,cold')]
    [TestCase('sr-finddata snapshot', 'sr-finddata,snapshot')]
    [TestCase('sr-finddata sessioncold', 'sr-finddata,sessioncold')]
    [TestCase('sr-finddata sessionwarm', 'sr-finddata,sessionwarm')]
    [TestCase('sr-finddata standalone', 'sr-finddata,standalone')]
    [TestCase('sr-finddata rootcold', 'sr-finddata,rootcold')]
    [TestCase('sr-finddata-fillchar cold', 'sr-finddata-fillchar,cold')]
    [TestCase('sr-finddata-fillchar snapshot', 'sr-finddata-fillchar,snapshot')]
    [TestCase('sr-finddata-fillchar sessioncold', 'sr-finddata-fillchar,sessioncold')]
    [TestCase('sr-finddata-fillchar sessionwarm', 'sr-finddata-fillchar,sessionwarm')]
    [TestCase('sr-finddata-fillchar standalone', 'sr-finddata-fillchar,standalone')]
    [TestCase('sr-finddata-fillchar rootcold', 'sr-finddata-fillchar,rootcold')]
    [TestCase('sr-timestamp cold', 'sr-timestamp,cold')]
    [TestCase('sr-timestamp snapshot', 'sr-timestamp,snapshot')]
    [TestCase('sr-timestamp sessioncold', 'sr-timestamp,sessioncold')]
    [TestCase('sr-timestamp sessionwarm', 'sr-timestamp,sessionwarm')]
    [TestCase('sr-timestamp standalone', 'sr-timestamp,standalone')]
    [TestCase('sr-timestamp rootcold', 'sr-timestamp,rootcold')]
    [TestCase('comp-tag-read namedcold', 'comp-tag-read,namedcold')]
    [TestCase('comp-tag-write namedcold', 'comp-tag-write,namedcold')]
    [TestCase('comp-name-read namedcold', 'comp-name-read,namedcold')]
    [TestCase('comp-owner-read namedcold', 'comp-owner-read,namedcold')]
    [TestCase('comp-tag-noglobal namedcold', 'comp-tag-noglobal,namedcold')]
    [TestCase('comp-2level-tag namedcold', 'comp-2level-tag,namedcold')]
    [TestCase('comp-method-call namedcold', 'comp-method-call,namedcold')]
    [TestCase('intf-refcount namedcold', 'intf-refcount,namedcold')]
    [TestCase('obj-classname-implicit namedcold', 'obj-classname-implicit,namedcold')]
    [TestCase('obj-classname-explicit namedcold', 'obj-classname-explicit,namedcold')]
    [TestCase('anc-weak-alias-tag namedcold', 'anc-weak-alias-tag,namedcold')]
    [TestCase('anc-strong-alias-tag namedcold', 'anc-strong-alias-tag,namedcold')]
    [TestCase('nested-outerrec-has-tag namedcold', 'nested-outerrec-has-tag,namedcold')]
    [TestCase('comp-in-method namedcold', 'comp-in-method,namedcold')]
    [TestCase('alias-projclass-classname namedcold', 'alias-projclass-classname,namedcold')]
    [TestCase('sr-excludeattr namedcold', 'sr-excludeattr,namedcold')]
    [TestCase('sr-findhandle namedcold', 'sr-findhandle,namedcold')]
    [TestCase('sr-finddata namedcold', 'sr-finddata,namedcold')]
    [TestCase('sr-finddata-fillchar namedcold', 'sr-finddata-fillchar,namedcold')]
    [TestCase('sr-timestamp namedcold', 'sr-timestamp,namedcold')]
    [TestCase('ctl-comp-own-member cold', 'ctl-comp-own-member,cold')]
    [TestCase('ctl-comp-own-member snapshot', 'ctl-comp-own-member,snapshot')]
    [TestCase('ctl-comp-own-member sessioncold', 'ctl-comp-own-member,sessioncold')]
    [TestCase('ctl-comp-own-member sessionwarm', 'ctl-comp-own-member,sessionwarm')]
    [TestCase('ctl-comp-own-member standalone', 'ctl-comp-own-member,standalone')]
    [TestCase('ctl-comp-own-member rootcold', 'ctl-comp-own-member,rootcold')]
    [TestCase('ctl-comp-own-member namedcold', 'ctl-comp-own-member,namedcold')]
    [TestCase('ctl-obj-own-member cold', 'ctl-obj-own-member,cold')]
    [TestCase('ctl-obj-own-member snapshot', 'ctl-obj-own-member,snapshot')]
    [TestCase('ctl-obj-own-member sessioncold', 'ctl-obj-own-member,sessioncold')]
    [TestCase('ctl-obj-own-member sessionwarm', 'ctl-obj-own-member,sessionwarm')]
    [TestCase('ctl-obj-own-member standalone', 'ctl-obj-own-member,standalone')]
    [TestCase('ctl-obj-own-member rootcold', 'ctl-obj-own-member,rootcold')]
    [TestCase('ctl-obj-own-member namedcold', 'ctl-obj-own-member,namedcold')]
    [TestCase('ctl-record-absent-global cold', 'ctl-record-absent-global,cold')]
    [TestCase('ctl-record-absent-global snapshot', 'ctl-record-absent-global,snapshot')]
    [TestCase('ctl-record-absent-global sessioncold', 'ctl-record-absent-global,sessioncold')]
    [TestCase('ctl-record-absent-global sessionwarm', 'ctl-record-absent-global,sessionwarm')]
    [TestCase('ctl-record-absent-global standalone', 'ctl-record-absent-global,standalone')]
    [TestCase('ctl-record-absent-global rootcold', 'ctl-record-absent-global,rootcold')]
    [TestCase('ctl-record-absent-global namedcold', 'ctl-record-absent-global,namedcold')]
    [TestCase('ctl-alias-projrec-field cold', 'ctl-alias-projrec-field,cold')]
    [TestCase('ctl-alias-projrec-field snapshot', 'ctl-alias-projrec-field,snapshot')]
    [TestCase('ctl-alias-projrec-field sessioncold', 'ctl-alias-projrec-field,sessioncold')]
    [TestCase('ctl-alias-projrec-field sessionwarm', 'ctl-alias-projrec-field,sessionwarm')]
    [TestCase('ctl-alias-projrec-field standalone', 'ctl-alias-projrec-field,standalone')]
    [TestCase('ctl-alias-projrec-field rootcold', 'ctl-alias-projrec-field,rootcold')]
    [TestCase('ctl-alias-projrec-field namedcold', 'ctl-alias-projrec-field,namedcold')]
    [TestCase('nested-innerrec-tag-ctl cold', 'nested-innerrec-tag-ctl,cold')]
    [TestCase('nested-innerrec-tag-ctl snapshot', 'nested-innerrec-tag-ctl,snapshot')]
    [TestCase('nested-innerrec-tag-ctl sessioncold', 'nested-innerrec-tag-ctl,sessioncold')]
    [TestCase('nested-innerrec-tag-ctl sessionwarm', 'nested-innerrec-tag-ctl,sessionwarm')]
    [TestCase('nested-innerrec-tag-ctl standalone', 'nested-innerrec-tag-ctl,standalone')]
    [TestCase('nested-innerrec-tag-ctl rootcold', 'nested-innerrec-tag-ctl,rootcold')]
    [TestCase('nested-innerrec-tag-ctl namedcold', 'nested-innerrec-tag-ctl,namedcold')]
    [TestCase('ctl-rec-in-comp-method-free cold', 'ctl-rec-in-comp-method-free,cold')]
    [TestCase('ctl-rec-in-comp-method-free snapshot', 'ctl-rec-in-comp-method-free,snapshot')]
    [TestCase('ctl-rec-in-comp-method-free sessioncold', 'ctl-rec-in-comp-method-free,sessioncold')]
    [TestCase('ctl-rec-in-comp-method-free sessionwarm', 'ctl-rec-in-comp-method-free,sessionwarm')]
    [TestCase('ctl-rec-in-comp-method-free standalone', 'ctl-rec-in-comp-method-free,standalone')]
    [TestCase('ctl-rec-in-comp-method-free rootcold', 'ctl-rec-in-comp-method-free,rootcold')]
    [TestCase('ctl-rec-in-comp-method-free namedcold', 'ctl-rec-in-comp-method-free,namedcold')]
    [TestCase('sr-name-ctl cold', 'sr-name-ctl,cold')]
    [TestCase('sr-name-ctl snapshot', 'sr-name-ctl,snapshot')]
    [TestCase('sr-name-ctl sessioncold', 'sr-name-ctl,sessioncold')]
    [TestCase('sr-name-ctl sessionwarm', 'sr-name-ctl,sessionwarm')]
    [TestCase('sr-name-ctl standalone', 'sr-name-ctl,standalone')]
    [TestCase('sr-name-ctl rootcold', 'sr-name-ctl,rootcold')]
    [TestCase('sr-name-ctl namedcold', 'sr-name-ctl,namedcold')]
    [TestCase('sr-fileio715 cold', 'sr-fileio715,cold')]
    [TestCase('sr-fileio715 snapshot', 'sr-fileio715,snapshot')]
    [TestCase('sr-fileio715 sessioncold', 'sr-fileio715,sessioncold')]
    [TestCase('sr-fileio715 sessionwarm', 'sr-fileio715,sessionwarm')]
    [TestCase('sr-fileio715 standalone', 'sr-fileio715,standalone')]
    [TestCase('sr-fileio715 rootcold', 'sr-fileio715,rootcold')]
    [TestCase('sr-fileio715 namedcold', 'sr-fileio715,namedcold')]
    [TestCase('ctl-obj-absent-global cold', 'ctl-obj-absent-global,cold')]
    [TestCase('ctl-obj-absent-global snapshot', 'ctl-obj-absent-global,snapshot')]
    [TestCase('ctl-obj-absent-global sessioncold', 'ctl-obj-absent-global,sessioncold')]
    [TestCase('ctl-obj-absent-global sessionwarm', 'ctl-obj-absent-global,sessionwarm')]
    [TestCase('ctl-obj-absent-global standalone', 'ctl-obj-absent-global,standalone')]
    [TestCase('ctl-obj-absent-global rootcold', 'ctl-obj-absent-global,rootcold')]
    [TestCase('ctl-obj-absent-global namedcold', 'ctl-obj-absent-global,namedcold')]
    [TestCase('obj-local-var-ctl cold', 'obj-local-var-ctl,cold')]
    [TestCase('obj-local-var-ctl snapshot', 'obj-local-var-ctl,snapshot')]
    [TestCase('obj-local-var-ctl sessioncold', 'obj-local-var-ctl,sessioncold')]
    [TestCase('obj-local-var-ctl sessionwarm', 'obj-local-var-ctl,sessionwarm')]
    [TestCase('obj-local-var-ctl standalone', 'obj-local-var-ctl,standalone')]
    [TestCase('obj-local-var-ctl rootcold', 'obj-local-var-ctl,rootcold')]
    [TestCase('obj-local-var-ctl namedcold', 'obj-local-var-ctl,namedcold')]
    [TestCase('ctl-comp-absent-global cold', 'ctl-comp-absent-global,cold')]
    [TestCase('ctl-comp-absent-global snapshot', 'ctl-comp-absent-global,snapshot')]
    [TestCase('ctl-comp-absent-global sessioncold', 'ctl-comp-absent-global,sessioncold')]
    [TestCase('ctl-comp-absent-global sessionwarm', 'ctl-comp-absent-global,sessionwarm')]
    [TestCase('ctl-comp-absent-global standalone', 'ctl-comp-absent-global,standalone')]
    [TestCase('ctl-comp-absent-global rootcold', 'ctl-comp-absent-global,rootcold')]
    [TestCase('ctl-comp-absent-global namedcold', 'ctl-comp-absent-global,namedcold')]
    [TestCase('comp-local-var cold', 'comp-local-var,cold')]
    [TestCase('comp-local-var snapshot', 'comp-local-var,snapshot')]
    [TestCase('comp-local-var sessioncold', 'comp-local-var,sessioncold')]
    [TestCase('comp-local-var sessionwarm', 'comp-local-var,sessionwarm')]
    [TestCase('comp-local-var standalone', 'comp-local-var,standalone')]
    [TestCase('comp-local-var rootcold', 'comp-local-var,rootcold')]
    [TestCase('comp-local-var namedcold', 'comp-local-var,namedcold')]
    [TestCase('comp-same-name-field-ctl cold', 'comp-same-name-field-ctl,cold')]
    [TestCase('comp-same-name-field-ctl snapshot', 'comp-same-name-field-ctl,snapshot')]
    [TestCase('comp-same-name-field-ctl sessioncold', 'comp-same-name-field-ctl,sessioncold')]
    [TestCase('comp-same-name-field-ctl sessionwarm', 'comp-same-name-field-ctl,sessionwarm')]
    [TestCase('comp-same-name-field-ctl standalone', 'comp-same-name-field-ctl,standalone')]
    [TestCase('comp-same-name-field-ctl rootcold', 'comp-same-name-field-ctl,rootcold')]
    [TestCase('comp-same-name-field-ctl namedcold', 'comp-same-name-field-ctl,namedcold')]
    [TestCase('nested-outerrec-field-b cold', 'nested-outerrec-field-b,cold')]
    [TestCase('nested-outerrec-field-b snapshot', 'nested-outerrec-field-b,snapshot')]
    [TestCase('nested-outerrec-field-b sessioncold', 'nested-outerrec-field-b,sessioncold')]
    [TestCase('nested-outerrec-field-b sessionwarm', 'nested-outerrec-field-b,sessionwarm')]
    [TestCase('nested-outerrec-field-b standalone', 'nested-outerrec-field-b,standalone')]
    [TestCase('nested-outerrec-field-b rootcold', 'nested-outerrec-field-b,rootcold')]
    [TestCase('nested-outerrec-field-b namedcold', 'nested-outerrec-field-b,namedcold')]
    [TestCase('nested-inner-absent-ctl cold', 'nested-inner-absent-ctl,cold')]
    [TestCase('nested-inner-absent-ctl snapshot', 'nested-inner-absent-ctl,snapshot')]
    [TestCase('nested-inner-absent-ctl sessioncold', 'nested-inner-absent-ctl,sessioncold')]
    [TestCase('nested-inner-absent-ctl sessionwarm', 'nested-inner-absent-ctl,sessionwarm')]
    [TestCase('nested-inner-absent-ctl standalone', 'nested-inner-absent-ctl,standalone')]
    [TestCase('nested-inner-absent-ctl namedcold', 'nested-inner-absent-ctl,namedcold')]
    [TestCase('nested-inner-tag cold', 'nested-inner-tag,cold')]
    [TestCase('nested-inner-tag snapshot', 'nested-inner-tag,snapshot')]
    [TestCase('nested-inner-tag sessioncold', 'nested-inner-tag,sessioncold')]
    [TestCase('nested-inner-tag sessionwarm', 'nested-inner-tag,sessionwarm')]
    [TestCase('nested-inner-tag standalone', 'nested-inner-tag,standalone')]
    [TestCase('nested-inner-tag rootcold', 'nested-inner-tag,rootcold')]
    [TestCase('nested-inner-tag namedcold', 'nested-inner-tag,namedcold')]
    [Category('DS742')]
    procedure RtlRootReceiverMembersQualifyOrRefuse(const aShape, aMode: string);
    [Test]
    [Category('DS742')]
    procedure RootMemberAbsenceProofIsSiteScoped;
    [TestCase('Visible procedure', 'True')]
    [TestCase('Missing procedure', 'False')]
    [Category('DS742Fix1b')]
    procedure NamedRootProcedureCallsRequireVisibleDeclaration(const aDeclared: Boolean);
    [TestCase('obj-open named', 'obj-open,named')]
    [TestCase('obj-open missing', 'obj-open,missing')]
    [TestCase('obj-open throw', 'obj-open,throw')]
    [TestCase('obj-open empty', 'obj-open,empty')]
    [TestCase('obj-open implicit', 'obj-open,implicit')]
    [TestCase('obj-unresolved named', 'obj-unresolved,named')]
    [TestCase('obj-unresolved missing', 'obj-unresolved,missing')]
    [TestCase('obj-unresolved throw', 'obj-unresolved,throw')]
    [TestCase('obj-unresolved empty', 'obj-unresolved,empty')]
    [TestCase('obj-unresolved implicit', 'obj-unresolved,implicit')]
    [TestCase('component named', 'component,named')]
    [TestCase('component missing', 'component,missing')]
    [TestCase('component throw', 'component,throw')]
    [TestCase('component empty', 'component,empty')]
    [TestCase('component implicit', 'component,implicit')]
    [TestCase('component-member named', 'component-member,named')]
    [TestCase('component-member missing', 'component-member,missing')]
    [TestCase('component-member throw', 'component-member,throw')]
    [TestCase('component-member empty', 'component-member,empty')]
    [TestCase('component-member implicit', 'component-member,implicit')]
    [TestCase('bitmap-order named', 'bitmap-order,named')]
    [TestCase('bitmap-order missing', 'bitmap-order,missing')]
    [TestCase('bitmap-order throw', 'bitmap-order,throw')]
    [TestCase('bitmap-order empty', 'bitmap-order,empty')]
    [TestCase('bitmap-order implicit', 'bitmap-order,implicit')]
    [TestCase('explicit-object named', 'explicit-object,named')]
    [TestCase('explicit-object missing', 'explicit-object,missing')]
    [TestCase('explicit-object throw', 'explicit-object,throw')]
    [TestCase('explicit-object empty', 'explicit-object,empty')]
    [TestCase('explicit-object implicit', 'explicit-object,implicit')]
    [TestCase('interface named', 'interface,named')]
    [TestCase('interface missing', 'interface,missing')]
    [TestCase('interface throw', 'interface,throw')]
    [TestCase('interface empty', 'interface,empty')]
    [TestCase('interface implicit', 'interface,implicit')]
    [TestCase('explicit-interface named', 'explicit-interface,named')]
    [TestCase('explicit-interface missing', 'explicit-interface,missing')]
    [TestCase('explicit-interface throw', 'explicit-interface,throw')]
    [TestCase('explicit-interface empty', 'explicit-interface,empty')]
    [TestCase('explicit-interface implicit', 'explicit-interface,implicit')]
    [TestCase('exception named', 'exception,named')]
    [TestCase('exception missing', 'exception,missing')]
    [TestCase('exception throw', 'exception,throw')]
    [TestCase('exception empty', 'exception,empty')]
    [TestCase('exception implicit', 'exception,implicit')]
    [TestCase('implementation named', 'implementation,named')]
    [TestCase('implementation missing', 'implementation,missing')]
    [TestCase('implementation throw', 'implementation,throw')]
    [TestCase('implementation empty', 'implementation,empty')]
    [TestCase('implementation implicit', 'implementation,implicit')]
    [TestCase('closed named', 'closed,named')]
    [TestCase('closed missing', 'closed,missing')]
    [TestCase('closed throw', 'closed,throw')]
    [TestCase('closed empty', 'closed,empty')]
    [TestCase('closed implicit', 'closed,implicit')]
    [TestCase('site-helper named', 'site-helper,named')]
    [TestCase('site-helper missing', 'site-helper,missing')]
    [TestCase('site-helper throw', 'site-helper,throw')]
    [TestCase('site-helper empty', 'site-helper,empty')]
    [TestCase('site-helper implicit', 'site-helper,implicit')]
    [TestCase('lookup-shadow named', 'lookup-shadow,named')]
    [TestCase('lookup-shadow missing', 'lookup-shadow,missing')]
    [TestCase('lookup-shadow throw', 'lookup-shadow,throw')]
    [TestCase('lookup-shadow empty', 'lookup-shadow,empty')]
    [TestCase('lookup-shadow implicit', 'lookup-shadow,implicit')]
    [TestCase('generic-base generic', 'generic-base,named')]
    [TestCase('generic-chain generic', 'generic-chain,named')]
    [Category('DS742')]
    procedure NamedRootReceiverMembersUseProviderEvidence(const aShape, aMode: string);

    // DS-750 characterization: the fail-closed behavior already exists at HEAD.
    [TestCase('list-add conventional cold', 'list-add,False,cold')]
    [TestCase('list-add conventional snapshot', 'list-add,False,snapshot')]
    [TestCase('list-add conventional standalone', 'list-add,False,standalone')]
    [TestCase('list-add conventional sessioncold', 'list-add,False,sessioncold')]
    [TestCase('list-add conventional sessionwarm', 'list-add,False,sessionwarm')]
    [TestCase('list-add compact cold', 'list-add,True,cold')]
    [TestCase('list-add compact snapshot', 'list-add,True,snapshot')]
    [TestCase('list-add compact standalone', 'list-add,True,standalone')]
    [TestCase('list-add compact sessioncold', 'list-add,True,sessioncold')]
    [TestCase('list-add compact sessionwarm', 'list-add,True,sessionwarm')]
    [TestCase('list-count conventional cold', 'list-count,False,cold')]
    [TestCase('list-count conventional snapshot', 'list-count,False,snapshot')]
    [TestCase('list-count conventional standalone', 'list-count,False,standalone')]
    [TestCase('list-count conventional sessioncold', 'list-count,False,sessioncold')]
    [TestCase('list-count conventional sessionwarm', 'list-count,False,sessionwarm')]
    [TestCase('list-count compact cold', 'list-count,True,cold')]
    [TestCase('list-count compact snapshot', 'list-count,True,snapshot')]
    [TestCase('list-count compact standalone', 'list-count,True,standalone')]
    [TestCase('list-count compact sessioncold', 'list-count,True,sessioncold')]
    [TestCase('list-count compact sessionwarm', 'list-count,True,sessionwarm')]
    [TestCase('list-items conventional cold', 'list-items,False,cold')]
    [TestCase('list-items conventional snapshot', 'list-items,False,snapshot')]
    [TestCase('list-items conventional standalone', 'list-items,False,standalone')]
    [TestCase('list-items conventional sessioncold', 'list-items,False,sessioncold')]
    [TestCase('list-items conventional sessionwarm', 'list-items,False,sessionwarm')]
    [TestCase('list-items compact cold', 'list-items,True,cold')]
    [TestCase('list-items compact snapshot', 'list-items,True,snapshot')]
    [TestCase('list-items compact standalone', 'list-items,True,standalone')]
    [TestCase('list-items compact sessioncold', 'list-items,True,sessioncold')]
    [TestCase('list-items compact sessionwarm', 'list-items,True,sessionwarm')]
    [TestCase('dictionary conventional cold', 'dictionary,False,cold')]
    [TestCase('dictionary conventional snapshot', 'dictionary,False,snapshot')]
    [TestCase('dictionary conventional standalone', 'dictionary,False,standalone')]
    [TestCase('dictionary conventional sessioncold', 'dictionary,False,sessioncold')]
    [TestCase('dictionary conventional sessionwarm', 'dictionary,False,sessionwarm')]
    [TestCase('dictionary compact cold', 'dictionary,True,cold')]
    [TestCase('dictionary compact snapshot', 'dictionary,True,snapshot')]
    [TestCase('dictionary compact standalone', 'dictionary,True,standalone')]
    [TestCase('dictionary compact sessioncold', 'dictionary,True,sessioncold')]
    [TestCase('dictionary compact sessionwarm', 'dictionary,True,sessionwarm')]
    [TestCase('project-depth1 conventional cold', 'project-depth1,False,cold')]
    [TestCase('project-depth1 conventional snapshot', 'project-depth1,False,snapshot')]
    [TestCase('project-depth1 conventional sessioncold', 'project-depth1,False,sessioncold')]
    [TestCase('project-depth1 conventional sessionwarm', 'project-depth1,False,sessionwarm')]
    [TestCase('project-depth1 compact cold', 'project-depth1,True,cold')]
    [TestCase('project-depth1 compact snapshot', 'project-depth1,True,snapshot')]
    [TestCase('project-depth1 compact sessioncold', 'project-depth1,True,sessioncold')]
    [TestCase('project-depth1 compact sessionwarm', 'project-depth1,True,sessionwarm')]
    [TestCase('project-depth2 conventional cold', 'project-depth2,False,cold')]
    [TestCase('project-depth2 conventional snapshot', 'project-depth2,False,snapshot')]
    [TestCase('project-depth2 conventional sessioncold', 'project-depth2,False,sessioncold')]
    [TestCase('project-depth2 conventional sessionwarm', 'project-depth2,False,sessionwarm')]
    [TestCase('project-depth2 compact cold', 'project-depth2,True,cold')]
    [TestCase('project-depth2 compact snapshot', 'project-depth2,True,snapshot')]
    [TestCase('project-depth2 compact sessioncold', 'project-depth2,True,sessioncold')]
    [TestCase('project-depth2 compact sessionwarm', 'project-depth2,True,sessionwarm')]
    [Category('DS750Characterization')]
    procedure GenericAncestorHomonymsRefuse(const aShape: string;
      const aCompact: Boolean; const aMode: string);

    [Test]
    [Category('DS742')]
    procedure NamedRootSiteHelperPrecedenceIsPreserved;
    [Test]
    [Category('DS742')]
    procedure NamedRootCaptureUsesRootMostDeclaration;

    [TestCase('Closed resolved include', 'closed')]
    [TestCase('Named resolved declaration include', 'declaration')]
    [TestCase('Named resolved site include', 'site')]
    [TestCase('Unresolved declaration include visibility control', 'unresolved')]
    [Category('DS742Fix5')]
    procedure RootProofIncludesUseExpandedScope(const aShape: string);

    [TestCase('Declaration captured private getter property', 'False')]
    [TestCase('Site visible private getter property', 'True')]
    [Category('DS742Fix5')]
    procedure NamedRootPrivateGetterPropertyScopes(const aSiteHelper: Boolean);

    [TestCase('n-ifdef-unicode', 'n-ifdef-unicode')]
    [TestCase('n-inc-ifdef-unicode', 'n-inc-ifdef-unicode')]
    [TestCase('n-inc-define-unknown', 'n-inc-define-unknown')]
    [TestCase('n-if-compilerversion', 'n-if-compilerversion')]
    [TestCase('c-ifdef-unicode', 'c-ifdef-unicode')]
    [TestCase('c-inc-ifdef-unicode', 'c-inc-ifdef-unicode')]
    [TestCase('site-unresolved', 'site-unresolved')]
    [TestCase('n-inc-define', 'n-inc-define')]
    [TestCase('n-inc-nested', 'n-inc-nested')]
    [TestCase('n-project-define', 'n-project-define')]
    [TestCase('c-none', 'c-none')]
    [TestCase('d-ifdef-unicode', 'd-ifdef-unicode')]
    [TestCase('d-inc-ifdef-unicode', 'd-inc-ifdef-unicode')]
    [TestCase('d-inc-define-unknown', 'd-inc-define-unknown')]
    [TestCase('d-if-compilerversion', 'd-if-compilerversion')]
    [TestCase('n-helper-declaration', 'n-helper-declaration')]
    [TestCase('c-helper-declaration', 'c-helper-declaration')]
    [TestCase('n-routine-unicode', 'n-routine-unicode')]
    [TestCase('n-unmatched', 'n-unmatched')]
    [TestCase('n-unterminated', 'n-unterminated')]
    [TestCase('n-unsupported', 'n-unsupported')]
    [Category('DS742Fix6')]
    procedure RootProofRequiresVerifiedPreprocessScope(const aShape: string);

    [TestCase('n-plain-other-unit', 'n-plain-other-unit')]
    [TestCase('n-ifopt', 'n-ifopt')]
    [TestCase('k-ifopt-site-body', 'k-ifopt-site-body')]
    [TestCase('k-hints-site', 'k-hints-site')]
    [TestCase('k-inline-site', 'k-inline-site')]
    [TestCase('k-hints-unit3', 'k-hints-unit3')]
    [TestCase('k-direct-known', 'k-direct-known')]
    [TestCase('k-ifopt-other-unit', 'k-ifopt-other-unit')]
    [Category('DS742Fix7')]
    procedure FailedModelCannotBypassRootAbsenceProof(const aShape: string);

    [TestCase('packed-local', 'packed-local')]
    [TestCase('unit-record', 'unit-record')]
    [TestCase('variant', 'variant')]
    [TestCase('nested', 'nested')]
    [TestCase('ifopt', 'ifopt')]
    [TestCase('ifdef', 'ifdef')]
    [TestCase('undefined-symbol', 'undefined-symbol')]
    [TestCase('i-plus', 'i-plus')]
    [TestCase('i-minus', 'i-minus')]
    [TestCase('record-comments', 'record-comments')]
    [TestCase('failed-model', 'failed-model')]
    [TestCase('named', 'named')]
    [TestCase('alias', 'alias')]
    [Category('DS742Fix7b')]
    procedure AnonymousRecordRequiresParsedEvidence(const aShape: string);

    [Test]
    [Category('DS731Planner')]
    procedure ValueMemberWithoutReceiverMatchRemovesCandidate;
    [TestCase('foreign field owner', 'foreign')]
    [TestCase('outer field homonym', 'homonym')]
    [Category('DS741Planner')]
    procedure AliasFieldUsesDeclaredReceiverIdentity(const aCase: string);
    [TestCase('constant with temporary', 'constant,temp')]
    [TestCase('field with temporary', 'field,temp')]
    [TestCase('constant with direct child', 'constant,direct')]
    [Category('DS740')]
    procedure RetainedSameLineParentKeepsChildScope(const aMember, aStrategy: string);
    [TestCase('split do', 'split-do')]
    [TestCase('preceding statement', 'prefix-stmt-parent')]
    [TestCase('false guard', 'np2-if')]
    [TestCase('if then else', 'if-then-else')]
    [TestCase('case label', 'case-label')]
    [TestCase('three levels', 'three-planned-mid')]
    [TestCase('two children', 'two-children')]
    [TestCase('following statement separator', 'following-stmt')]
    [TestCase('outer else', 'outer-if-else-sameline')]
    [TestCase('planned parent absorbs multi-statement child', 'planned-parent')]
    [Category('DS740')]
    procedure PrefixedWithKeepsControlledStatement(const aCase: string);
    [TestCase('known inactive controlling prefix', 'inactive')]
    [TestCase('known active controlling prefix', 'active')]
    [TestCase('unknown controlling prefix', 'unknown')]
    [TestCase('NET statement prefix', 'net-statement')]
    [TestCase('NET controlling prefix', 'net-control')]
    [TestCase('two adjacent statement spans', 'two-statements')]
    [TestCase('two adjacent spans exposing control', 'two-control')]
    [TestCase('complementary active span exposes control', 'complementary-control')]
    [TestCase('active span after conditional control', 'active-control')]
    [TestCase('active span after unconditional separator', 'active-statement')]
    [TestCase('partial receiver cascade with handler DO', 'partial-cascade')]
    [TestCase('include controlling prefix', 'include')]
    [TestCase('while do controls', 'while')]
    [TestCase('same-line while do controls', 'while-inline')]
    [TestCase('same-line for do controls', 'for-inline')]
    [TestCase('for do controls', 'for')]
    [TestCase('routine inside conditional', 'routine-ifdef')]
    [TestCase('earlier expression conditional', 'expression-ifdef')]
    [TestCase('comments are trivia', 'comments')]
    [TestCase('directive text in string is not a directive', 'string')]
    [TestCase('label controls', 'label')]
    [TestCase('planned parent while child', 'planned-while')]
    [TestCase('planned parent for child', 'planned-for')]
    [TestCase('planned parent exception child', 'planned-on')]
    [TestCase('refused parent with planned siblings', 'cb-sib')]
    [Category('DS740PrefixActivity')]
    procedure PrefixControlUsesActivity(const aActivity: string);

    [TestCase('conflicting identities', 'conflict')]
    [TestCase('retained member', 'retained')]
    [Category('DS731Planner')]
    procedure ValueMemberReceiverDecisions(const aCase: string);
    [TestCase('rc-sameline-peer', 'rc-sameline-peer')]
    [TestCase('rc-section-multiline', 'rc-section-multiline')]
    [TestCase('rc-imported-recv', 'rc-imported-recv')]
    [TestCase('rc-private-same-unit', 'rc-private-same-unit')]
    [TestCase('vt-local-record', 'vt-local-record')]
    [TestCase('cc-global-read', 'cc-global-read')]
    [TestCase('cc-inherited-import', 'cc-inherited-import')]
    [TestCase('cc-derived-const', 'cc-derived-const')]
    [TestCase('rc-local', 'rc-local')]
    [TestCase('vt-nested-variant', 'vt-nested-variant')]
    [TestCase('cc-private-import', 'cc-private-import')]
    [TestCase('cc-strict-private-same-unit', 'cc-strict-private-same-unit')]
    [TestCase('cc-protected-descendant', 'cc-protected-descendant')]
    [TestCase('rc-helper-const', 'rc-helper-const')]
    [TestCase('lost-constant', 'lost-constant')]
    [TestCase('rc-unit-const-ctl', 'rc-unit-const-ctl')]
    [TestCase('rc-foreign-homonym', 'rc-foreign-homonym')]
    [TestCase('rc-nested-type-neg', 'rc-nested-type-neg')]
    [TestCase('vt-inline-field-neg', 'vt-inline-field-neg')]
    [TestCase('cc-derived-field-hides', 'cc-derived-field-hides')]
    [TestCase('rc-cond-inactive', 'rc-cond-inactive')]
    [TestCase('vt-tagless-field', 'vt-tagless-field')]
    [Category('DS731Safety')]
    procedure TypeValueSafetyAndSnapshot(const aShape: string);
    function TypeValueSafetyModels(const aShape: string): TArray<TDelphiSemanticUnitModel>;
    [TestCase('anonymous-global cold', 'anonymous-global,cold')]
    [TestCase('anonymous-global warm', 'anonymous-global,warm')]
    [TestCase('anonymous-global snapshot', 'anonymous-global,snapshot')]
    [TestCase('anonymous-local cold', 'anonymous-local,cold')]
    [TestCase('anonymous-local warm', 'anonymous-local,warm')]
    [TestCase('anonymous-local snapshot', 'anonymous-local,snapshot')]
    [TestCase('anonymous-control cold', 'anonymous-control,cold')]
    [TestCase('anonymous-control warm', 'anonymous-control,warm')]
    [TestCase('anonymous-control snapshot', 'anonymous-control,snapshot')]
    [TestCase('num-rec cold', 'num-rec,cold')]
    [TestCase('num-rec warm', 'num-rec,warm')]
    [TestCase('num-rec snapshot', 'num-rec,snapshot')]
    [TestCase('tag-only cold', 'tag-only,cold')]
    [TestCase('tag-only warm', 'tag-only,warm')]
    [TestCase('tag-only snapshot', 'tag-only,snapshot')]
    [TestCase('record-constant cold', 'record-constant,cold')]
    [TestCase('record-constant warm', 'record-constant,warm')]
    [TestCase('record-constant snapshot', 'record-constant,snapshot')]
    [TestCase('anonymous-include cold', 'anonymous-include,cold')]
    [TestCase('anonymous-include warm', 'anonymous-include,warm')]
    [TestCase('anonymous-include snapshot', 'anonymous-include,snapshot')]
    [TestCase('anonymous-inactive cold', 'anonymous-inactive,cold')]
    [TestCase('anonymous-inactive warm', 'anonymous-inactive,warm')]
    [TestCase('anonymous-inactive snapshot', 'anonymous-inactive,snapshot')]
    [TestCase('helper-unrelated cold', 'helper-unrelated,cold')]
    [TestCase('helper-unrelated warm', 'helper-unrelated,warm')]
    [TestCase('helper-unrelated snapshot', 'helper-unrelated,snapshot')]
    [TestCase('helper-own cold', 'helper-own,cold')]
    [TestCase('helper-own warm', 'helper-own,warm')]
    [TestCase('helper-own snapshot', 'helper-own,snapshot')]
    [Category('DS731Persistence')]
    [TestCase('unrelated-diagnostic cold', 'unrelated-diagnostic,cold')]
    [TestCase('unrelated-diagnostic warm', 'unrelated-diagnostic,warm')]
    [TestCase('unrelated-diagnostic snapshot', 'unrelated-diagnostic,snapshot')]
    [TestCase('receiver-diagnostic cold', 'receiver-diagnostic,cold')]
    [TestCase('receiver-diagnostic warm', 'receiver-diagnostic,warm')]
    [TestCase('receiver-diagnostic snapshot', 'receiver-diagnostic,snapshot')]
    [TestCase('class-tobject cold', 'class-tobject,cold')]
    [TestCase('class-tobject warm', 'class-tobject,warm')]
    [TestCase('class-tobject snapshot', 'class-tobject,snapshot')]
    [TestCase('class-interfaced cold', 'class-interfaced,cold')]
    [TestCase('class-interfaced warm', 'class-interfaced,warm')]
    [TestCase('class-interfaced snapshot', 'class-interfaced,snapshot')]
    [TestCase('class-component cold', 'class-component,cold')]
    [TestCase('class-component warm', 'class-component,warm')]
    [TestCase('class-component snapshot', 'class-component,snapshot')]
    [TestCase('class-forward cold', 'class-forward,cold')]
    [TestCase('class-forward warm', 'class-forward,warm')]
    [TestCase('class-forward snapshot', 'class-forward,snapshot')]
    [TestCase('indexed-field-control cold', 'indexed-field-control,cold')]
    [TestCase('indexed-field-control warm', 'indexed-field-control,warm')]
    [TestCase('indexed-field-control snapshot', 'indexed-field-control,snapshot')]
    [TestCase('indexed-named-tag cold', 'indexed-named-tag,cold')]
    [TestCase('indexed-named-tag warm', 'indexed-named-tag,warm')]
    [TestCase('indexed-named-tag snapshot', 'indexed-named-tag,snapshot')]
    [TestCase('indexed-inline-tag cold', 'indexed-inline-tag,cold')]
    [TestCase('indexed-inline-tag warm', 'indexed-inline-tag,warm')]
    [TestCase('indexed-inline-tag snapshot', 'indexed-inline-tag,snapshot')]
    [TestCase('strong-alias-qualified-target cold', 'strong-alias-qualified-target,cold')]
    [TestCase('strong-alias-qualified-target warm', 'strong-alias-qualified-target,warm')]
    [TestCase('strong-alias-qualified-target snapshot', 'strong-alias-qualified-target,snapshot')]
    [TestCase('anonymous-declaration-include cold', 'anonymous-declaration-include,cold')]
    [TestCase('anonymous-declaration-include warm', 'anonymous-declaration-include,warm')]
    [TestCase('anonymous-declaration-include snapshot', 'anonymous-declaration-include,snapshot')]
    [TestCase('anonymous-declaration-include-multiline cold', 'anonymous-declaration-include-multiline,cold')]
    [TestCase('anonymous-declaration-include-multiline warm', 'anonymous-declaration-include-multiline,warm')]
    [TestCase('anonymous-declaration-include-multiline snapshot', 'anonymous-declaration-include-multiline,snapshot')]
    [TestCase('anonymous-type-include cold', 'anonymous-type-include,cold')]
    [TestCase('anonymous-type-include warm', 'anonymous-type-include,warm')]
    [TestCase('anonymous-type-include snapshot', 'anonymous-type-include,snapshot')]
    [TestCase('anonymous-include-fields-only cold', 'anonymous-include-fields-only,cold')]
    [TestCase('anonymous-include-fields-only warm', 'anonymous-include-fields-only,warm')]
    [TestCase('anonymous-include-fields-only snapshot', 'anonymous-include-fields-only,snapshot')]
    [TestCase('anonymous-include-paren cold', 'anonymous-include-paren,cold')]
    [TestCase('anonymous-include-paren warm', 'anonymous-include-paren,warm')]
    [TestCase('anonymous-include-paren snapshot', 'anonymous-include-paren,snapshot')]
    [TestCase('inline-active-crlf cold', 'inline-active-crlf,cold')]
    [TestCase('inline-active-crlf warm', 'inline-active-crlf,warm')]
    [TestCase('inline-active-crlf snapshot', 'inline-active-crlf,snapshot')]
    [TestCase('inline-active-lf cold', 'inline-active-lf,cold')]
    [TestCase('inline-active-lf warm', 'inline-active-lf,warm')]
    [TestCase('inline-active-lf snapshot', 'inline-active-lf,snapshot')]
    [TestCase('inactive-tag-crlf cold', 'inactive-tag-crlf,cold')]
    [TestCase('inactive-tag-crlf warm', 'inactive-tag-crlf,warm')]
    [TestCase('inactive-tag-crlf snapshot', 'inactive-tag-crlf,snapshot')]
    [TestCase('inactive-tag-lf cold', 'inactive-tag-lf,cold')]
    [TestCase('inactive-tag-lf warm', 'inactive-tag-lf,warm')]
    [TestCase('inactive-tag-lf snapshot', 'inactive-tag-lf,snapshot')]
    [TestCase('inactive-include-crlf cold', 'inactive-include-crlf,cold')]
    [TestCase('inactive-include-crlf warm', 'inactive-include-crlf,warm')]
    [TestCase('inactive-include-crlf snapshot', 'inactive-include-crlf,snapshot')]
    [TestCase('inactive-include-lf cold', 'inactive-include-lf,cold')]
    [TestCase('inactive-include-lf warm', 'inactive-include-lf,warm')]
    [TestCase('inactive-include-lf snapshot', 'inactive-include-lf,snapshot')]
    [TestCase('class-var cold', 'class-var,cold')]
    [TestCase('class-var warm', 'class-var,warm')]
    [TestCase('class-var snapshot', 'class-var,snapshot')]
    [TestCase('instance-field cold', 'instance-field,cold')]
    [TestCase('instance-field warm', 'instance-field,warm')]
    [TestCase('instance-field snapshot', 'instance-field,snapshot')]
    procedure ValueMembersColdWarmSnapshot(const aShape, aMode: string);
    [Category('DS741AliasReceiver')]
    [TestCase('strong-helper-global cold', 'strong-helper-global,cold')]
    [TestCase('strong-helper-global snapshot', 'strong-helper-global,snapshot')]
    [TestCase('strong-helper-global sessioncold', 'strong-helper-global,sessioncold')]
    [TestCase('strong-helper-global sessionwarm', 'strong-helper-global,sessionwarm')]
    [TestCase('strong-helper-global standalone', 'strong-helper-global,standalone')]
    [TestCase('strong-own-helper-global cold', 'strong-own-helper-global,cold')]
    [TestCase('strong-own-helper-global snapshot', 'strong-own-helper-global,snapshot')]
    [TestCase('strong-own-helper-global sessioncold', 'strong-own-helper-global,sessioncold')]
    [TestCase('strong-own-helper-global sessionwarm', 'strong-own-helper-global,sessionwarm')]
    [TestCase('strong-own-helper-global standalone', 'strong-own-helper-global,standalone')]
    [TestCase('weak-var-globalA cold', 'weak-var-globalA,cold')]
    [TestCase('weak-var-globalA snapshot', 'weak-var-globalA,snapshot')]
    [TestCase('weak-var-globalA sessioncold', 'weak-var-globalA,sessioncold')]
    [TestCase('weak-var-globalA sessionwarm', 'weak-var-globalA,sessionwarm')]
    [TestCase('weak-var-globalA standalone', 'weak-var-globalA,standalone')]
    [TestCase('weak-var-noglobal cold', 'weak-var-noglobal,cold')]
    [TestCase('weak-var-noglobal snapshot', 'weak-var-noglobal,snapshot')]
    [TestCase('weak-var-noglobal sessioncold', 'weak-var-noglobal,sessioncold')]
    [TestCase('weak-var-noglobal sessionwarm', 'weak-var-noglobal,sessionwarm')]
    [TestCase('weak-var-noglobal standalone', 'weak-var-noglobal,standalone')]
    [TestCase('alias-varA-noconst-globalA cold', 'alias-varA-noconst-globalA,cold')]
    [TestCase('alias-varA-noconst-globalA snapshot', 'alias-varA-noconst-globalA,snapshot')]
    [TestCase('alias-varA-noconst-globalA sessioncold', 'alias-varA-noconst-globalA,sessioncold')]
    [TestCase('alias-varA-noconst-globalA sessionwarm', 'alias-varA-noconst-globalA,sessionwarm')]
    [TestCase('alias-varA-noconst-globalA standalone', 'alias-varA-noconst-globalA,standalone')]
    [TestCase('strong-plain-globalA cold', 'strong-plain-globalA,cold')]
    [TestCase('strong-plain-globalA snapshot', 'strong-plain-globalA,snapshot')]
    [TestCase('strong-plain-globalA sessioncold', 'strong-plain-globalA,sessioncold')]
    [TestCase('strong-plain-globalA sessionwarm', 'strong-plain-globalA,sessionwarm')]
    [TestCase('strong-plain-globalA standalone', 'strong-plain-globalA,standalone')]
    [TestCase('strong-plain-noglobal cold', 'strong-plain-noglobal,cold')]
    [TestCase('strong-plain-noglobal snapshot', 'strong-plain-noglobal,snapshot')]
    [TestCase('strong-plain-noglobal sessioncold', 'strong-plain-noglobal,sessioncold')]
    [TestCase('strong-plain-noglobal sessionwarm', 'strong-plain-noglobal,sessionwarm')]
    [TestCase('strong-plain-noglobal standalone', 'strong-plain-noglobal,standalone')]
    [TestCase('strong-var-globalA cold', 'strong-var-globalA,cold')]
    [TestCase('strong-var-globalA snapshot', 'strong-var-globalA,snapshot')]
    [TestCase('strong-var-globalA sessioncold', 'strong-var-globalA,sessioncold')]
    [TestCase('strong-var-globalA sessionwarm', 'strong-var-globalA,sessionwarm')]
    [TestCase('strong-var-globalA standalone', 'strong-var-globalA,standalone')]
    [TestCase('strong-plain-readglobal cold', 'strong-plain-readglobal,cold')]
    [TestCase('strong-plain-readglobal snapshot', 'strong-plain-readglobal,snapshot')]
    [TestCase('strong-plain-readglobal sessioncold', 'strong-plain-readglobal,sessioncold')]
    [TestCase('strong-plain-readglobal sessionwarm', 'strong-plain-readglobal,sessionwarm')]
    [TestCase('strong-plain-readglobal standalone', 'strong-plain-readglobal,standalone')]
    [TestCase('strong-class-globalA cold', 'strong-class-globalA,cold')]
    [TestCase('strong-class-globalA snapshot', 'strong-class-globalA,snapshot')]
    [TestCase('strong-class-globalA sessioncold', 'strong-class-globalA,sessioncold')]
    [TestCase('strong-class-globalA sessionwarm', 'strong-class-globalA,sessionwarm')]
    [TestCase('strong-class-globalA standalone', 'strong-class-globalA,standalone')]
    [TestCase('weak-varA-classvar-globalA cold', 'weak-varA-classvar-globalA,cold')]
    [TestCase('weak-varA-classvar-globalA snapshot', 'weak-varA-classvar-globalA,snapshot')]
    [TestCase('weak-varA-classvar-globalA sessioncold', 'weak-varA-classvar-globalA,sessioncold')]
    [TestCase('weak-varA-classvar-globalA sessionwarm', 'weak-varA-classvar-globalA,sessionwarm')]
    [TestCase('weak-varA-classvar-globalA standalone', 'weak-varA-classvar-globalA,standalone')]
    [TestCase('alias-varA-classvar-globalA cold', 'alias-varA-classvar-globalA,cold')]
    [TestCase('alias-varA-classvar-globalA snapshot', 'alias-varA-classvar-globalA,snapshot')]
    [TestCase('alias-varA-classvar-globalA sessioncold', 'alias-varA-classvar-globalA,sessioncold')]
    [TestCase('alias-varA-classvar-globalA sessionwarm', 'alias-varA-classvar-globalA,sessionwarm')]
    [TestCase('alias-varA-classvar-globalA standalone', 'alias-varA-classvar-globalA,standalone')]
    [TestCase('weak-chain-var-globalA cold', 'weak-chain-var-globalA,cold')]
    [TestCase('weak-chain-var-globalA snapshot', 'weak-chain-var-globalA,snapshot')]
    [TestCase('weak-chain-var-globalA sessioncold', 'weak-chain-var-globalA,sessioncold')]
    [TestCase('weak-chain-var-globalA sessionwarm', 'weak-chain-var-globalA,sessionwarm')]
    [TestCase('weak-chain-var-globalA standalone', 'weak-chain-var-globalA,standalone')]
    [TestCase('weak-cross-unit-var-globalA cold', 'weak-cross-unit-var-globalA,cold')]
    [TestCase('weak-cross-unit-var-globalA snapshot', 'weak-cross-unit-var-globalA,snapshot')]
    [TestCase('weak-cross-unit-var-globalA sessioncold', 'weak-cross-unit-var-globalA,sessioncold')]
    [TestCase('weak-cross-unit-var-globalA sessionwarm', 'weak-cross-unit-var-globalA,sessionwarm')]
    [TestCase('weak-cross-unit-var-globalA standalone', 'weak-cross-unit-var-globalA,standalone')]
    [TestCase('local-weak-var-globalA cold', 'local-weak-var-globalA,cold')]
    [TestCase('local-weak-var-globalA snapshot', 'local-weak-var-globalA,snapshot')]
    [TestCase('local-weak-var-globalA sessioncold', 'local-weak-var-globalA,sessioncold')]
    [TestCase('local-weak-var-globalA sessionwarm warm-unreachable DS743', 'local-weak-var-globalA,sessionwarm')]
    [TestCase('local-weak-var-globalA standalone warm-unreachable DS743', 'local-weak-var-globalA,standalone')]
    [TestCase('on-sib-a cold', 'on-sib-a,cold')]
    [TestCase('on-sib-a snapshot', 'on-sib-a,snapshot')]
    [TestCase('on-sib-a sessioncold', 'on-sib-a,sessioncold')]
    [TestCase('on-sib-a sessionwarm', 'on-sib-a,sessionwarm')]
    [TestCase('on-sib-a standalone', 'on-sib-a,standalone')]
    [TestCase('d-nested-twoline-noconst cold', 'd-nested-twoline-noconst,cold')]
    [TestCase('d-nested-twoline-noconst snapshot', 'd-nested-twoline-noconst,snapshot')]
    [TestCase('d-nested-twoline-noconst sessioncold', 'd-nested-twoline-noconst,sessioncold')]
    [TestCase('d-nested-twoline-noconst sessionwarm', 'd-nested-twoline-noconst,sessionwarm')]
    [TestCase('d-nested-twoline-noconst standalone', 'd-nested-twoline-noconst,standalone')]
    [TestCase('unit-local-weak-var-globalA cold', 'unit-local-weak-var-globalA,cold')]
    [TestCase('unit-local-weak-var-globalA snapshot', 'unit-local-weak-var-globalA,snapshot')]
    [TestCase('unit-local-weak-var-globalA sessioncold', 'unit-local-weak-var-globalA,sessioncold')]
    [TestCase('unit-local-weak-var-globalA sessionwarm', 'unit-local-weak-var-globalA,sessionwarm')]
    [TestCase('unit-local-weak-var-globalA standalone', 'unit-local-weak-var-globalA,standalone')]
    [TestCase('fix-helper-via-weak cold', 'fix-helper-via-weak,cold')]
    [TestCase('fix-helper-via-weak snapshot', 'fix-helper-via-weak,snapshot')]
    [TestCase('fix-helper-via-weak sessioncold', 'fix-helper-via-weak,sessioncold')]
    [TestCase('fix-helper-via-weak sessionwarm', 'fix-helper-via-weak,sessionwarm')]
    [TestCase('fix-helper-via-weak standalone', 'fix-helper-via-weak,standalone')]
    [TestCase('fix-generic-record cold', 'fix-generic-record,cold')]
    [TestCase('fix-generic-record snapshot', 'fix-generic-record,snapshot')]
    [TestCase('fix-generic-record sessioncold', 'fix-generic-record,sessioncold')]
    [TestCase('fix-generic-record sessionwarm', 'fix-generic-record,sessionwarm')]
    [TestCase('fix-generic-record standalone', 'fix-generic-record,standalone')]
    [TestCase('fix-generic-plain cold', 'fix-generic-plain,cold')]
    [TestCase('fix-generic-plain snapshot', 'fix-generic-plain,snapshot')]
    [TestCase('fix-generic-plain sessioncold', 'fix-generic-plain,sessioncold')]
    [TestCase('fix-generic-plain sessionwarm', 'fix-generic-plain,sessionwarm')]
    [TestCase('fix-generic-plain standalone', 'fix-generic-plain,standalone')]
    [TestCase('fix-generic-class cold', 'fix-generic-class,cold')]
    [TestCase('fix-generic-class snapshot', 'fix-generic-class,snapshot')]
    [TestCase('fix-generic-class sessioncold', 'fix-generic-class,sessioncold')]
    [TestCase('fix-generic-class sessionwarm', 'fix-generic-class,sessionwarm')]
    [TestCase('fix-generic-class standalone', 'fix-generic-class,standalone')]
    [TestCase('fix-escaped cold', 'fix-escaped,cold')]
    [TestCase('fix-escaped snapshot', 'fix-escaped,snapshot')]
    [TestCase('fix-escaped sessioncold', 'fix-escaped,sessioncold')]
    [TestCase('fix-escaped sessionwarm', 'fix-escaped,sessionwarm')]
    [TestCase('fix-escaped standalone', 'fix-escaped,standalone')]
    [TestCase('fix-sol-generic cold', 'fix-sol-generic,cold')]
    [TestCase('fix-sol-generic snapshot', 'fix-sol-generic,snapshot')]
    [TestCase('fix-sol-generic sessioncold', 'fix-sol-generic,sessioncold')]
    [TestCase('fix-sol-generic sessionwarm', 'fix-sol-generic,sessionwarm')]
    [TestCase('fix-sol-generic standalone', 'fix-sol-generic,standalone')]
    [TestCase('fix-local-strong cold', 'fix-local-strong,cold')]
    [TestCase('fix-local-strong snapshot', 'fix-local-strong,snapshot')]
    [TestCase('fix-local-strong sessioncold', 'fix-local-strong,sessioncold')]
    [TestCase('fix-local-strong sessionwarm', 'fix-local-strong,sessionwarm')]
    [TestCase('fix-local-strong standalone', 'fix-local-strong,standalone')]
    [TestCase('fix-helper-via-plain cold', 'fix-helper-via-plain,cold')]
    [TestCase('fix-helper-via-plain snapshot', 'fix-helper-via-plain,snapshot')]
    [TestCase('fix-helper-via-plain sessioncold', 'fix-helper-via-plain,sessioncold')]
    [TestCase('fix-helper-via-plain sessionwarm', 'fix-helper-via-plain,sessionwarm')]
    [TestCase('fix-helper-via-plain standalone', 'fix-helper-via-plain,standalone')]
    procedure AliasReceiverMembersBindAndPlan(const aShape, aMode: string);
    [Test]
    [Category('DS741AliasPrecedence')]
    procedure AliasRefusalPreservesLocalTypeReason;
    [Category('DS741Round2')]
    [TestCase('c-generic-alias-call-nongeneric-param cold', 'c-generic-alias-call-nongeneric-param,cold')]
    [TestCase('c-generic-alias-call-nongeneric-param snapshot', 'c-generic-alias-call-nongeneric-param,snapshot')]
    [TestCase('c-generic-alias-call-nongeneric-param sessioncold', 'c-generic-alias-call-nongeneric-param,sessioncold')]
    [TestCase('c-generic-alias-call-nongeneric-param sessionwarm', 'c-generic-alias-call-nongeneric-param,sessionwarm')]
    [TestCase('c-generic-alias-call-nongeneric-param standalone', 'c-generic-alias-call-nongeneric-param,standalone')]
    [TestCase('g-call-args cold', 'g-call-args,cold')]
    [TestCase('g-call-args snapshot', 'g-call-args,snapshot')]
    [TestCase('g-call-args sessioncold', 'g-call-args,sessioncold')]
    [TestCase('g-call-args sessionwarm', 'g-call-args,sessionwarm')]
    [TestCase('g-call-args standalone', 'g-call-args,standalone')]
    [TestCase('g-class-call cold', 'g-class-call,cold')]
    [TestCase('g-class-call snapshot', 'g-class-call,snapshot')]
    [TestCase('g-class-call sessioncold', 'g-class-call,sessioncold')]
    [TestCase('g-class-call sessionwarm', 'g-class-call,sessionwarm')]
    [TestCase('g-class-call standalone', 'g-class-call,standalone')]
    [TestCase('g-escaped-call cold', 'g-escaped-call,cold')]
    [TestCase('g-escaped-call snapshot', 'g-escaped-call,snapshot')]
    [TestCase('g-escaped-call sessioncold', 'g-escaped-call,sessioncold')]
    [TestCase('g-escaped-call sessionwarm', 'g-escaped-call,sessionwarm')]
    [TestCase('g-escaped-call standalone', 'g-escaped-call,standalone')]
    [TestCase('k-b-call-helper-via-weak cold', 'k-b-call-helper-via-weak,cold')]
    [TestCase('k-b-call-helper-via-weak snapshot', 'k-b-call-helper-via-weak,snapshot')]
    [TestCase('k-b-call-helper-via-weak sessioncold', 'k-b-call-helper-via-weak,sessioncold')]
    [TestCase('k-b-call-helper-via-weak sessionwarm', 'k-b-call-helper-via-weak,sessionwarm')]
    [TestCase('k-b-call-helper-via-weak standalone', 'k-b-call-helper-via-weak,standalone')]
    [TestCase('k-d3-call-own-helper cold', 'k-d3-call-own-helper,cold')]
    [TestCase('k-d3-call-own-helper snapshot', 'k-d3-call-own-helper,snapshot')]
    [TestCase('k-d3-call-own-helper sessioncold', 'k-d3-call-own-helper,sessioncold')]
    [TestCase('k-d3-call-own-helper sessionwarm', 'k-d3-call-own-helper,sessionwarm')]
    [TestCase('k-d3-call-own-helper standalone', 'k-d3-call-own-helper,standalone')]
    [TestCase('k-d3-call-target-helper cold', 'k-d3-call-target-helper,cold')]
    [TestCase('k-d3-call-target-helper snapshot', 'k-d3-call-target-helper,snapshot')]
    [TestCase('k-d3-call-target-helper sessioncold', 'k-d3-call-target-helper,sessioncold')]
    [TestCase('k-d3-call-target-helper sessionwarm', 'k-d3-call-target-helper,sessionwarm')]
    [TestCase('k-d3-call-target-helper standalone', 'k-d3-call-target-helper,standalone')]
    [TestCase('l-rtl-generic-alias-add cold', 'l-rtl-generic-alias-add,cold')]
    [TestCase('l-rtl-generic-alias-add snapshot', 'l-rtl-generic-alias-add,snapshot')]
    [TestCase('l-rtl-generic-alias-add sessioncold', 'l-rtl-generic-alias-add,sessioncold')]
    [TestCase('l-rtl-generic-alias-add sessionwarm', 'l-rtl-generic-alias-add,sessionwarm')]
    [TestCase('l-rtl-generic-alias-add standalone', 'l-rtl-generic-alias-add,standalone')]
    [TestCase('c-plain-call cold', 'c-plain-call,cold')]
    [TestCase('c-plain-call snapshot', 'c-plain-call,snapshot')]
    [TestCase('c-plain-call sessioncold', 'c-plain-call,sessioncold')]
    [TestCase('c-plain-call sessionwarm', 'c-plain-call,sessionwarm')]
    [TestCase('c-plain-call standalone', 'c-plain-call,standalone')]
    [TestCase('c-strong-call cold', 'c-strong-call,cold')]
    [TestCase('c-strong-call snapshot', 'c-strong-call,snapshot')]
    [TestCase('c-strong-call sessioncold', 'c-strong-call,sessioncold')]
    [TestCase('c-strong-call sessionwarm', 'c-strong-call,sessionwarm')]
    [TestCase('c-strong-call standalone', 'c-strong-call,standalone')]
    [TestCase('c-weak-call cold', 'c-weak-call,cold')]
    [TestCase('c-weak-call snapshot', 'c-weak-call,snapshot')]
    [TestCase('c-weak-call sessioncold', 'c-weak-call,sessioncold')]
    [TestCase('c-weak-call sessionwarm', 'c-weak-call,sessionwarm')]
    [TestCase('c-weak-call standalone', 'c-weak-call,standalone')]
    [TestCase('k-weak-call-helper cold', 'k-weak-call-helper,cold')]
    [TestCase('k-weak-call-helper snapshot', 'k-weak-call-helper,snapshot')]
    [TestCase('k-weak-call-helper sessioncold', 'k-weak-call-helper,sessioncold')]
    [TestCase('k-weak-call-helper sessionwarm', 'k-weak-call-helper,sessionwarm')]
    [TestCase('k-weak-call-helper standalone', 'k-weak-call-helper,standalone')]
    [TestCase('nested-local-strong cold', 'nested-local-strong,cold')]
    [TestCase('nested-local-strong snapshot', 'nested-local-strong,snapshot')]
    [TestCase('nested-local-strong sessioncold', 'nested-local-strong,sessioncold')]
    [TestCase('nested-local-strong sessionwarm', 'nested-local-strong,sessionwarm')]
    [TestCase('nested-local-strong standalone', 'nested-local-strong,standalone')]
    [TestCase('nested-local-weak cold', 'nested-local-weak,cold')]
    [TestCase('nested-local-weak snapshot', 'nested-local-weak,snapshot')]
    [TestCase('nested-local-weak sessioncold', 'nested-local-weak,sessioncold')]
    [TestCase('nested-local-weak sessionwarm warm-unreachable DS743', 'nested-local-weak,sessionwarm')]
    [TestCase('nested-local-weak standalone warm-unreachable DS743', 'nested-local-weak,standalone')]
    procedure AliasCallsAndCapturedAliases(const aShape, aMode: string);

    [Test]
    [Category('DS741Round3')]
    [TestCase('r5-inline-name cold', 'r5-inline-name,cold')]
    [TestCase('r5-inline-name snapshot', 'r5-inline-name,snapshot')]
    [TestCase('r5-inline-name sessioncold', 'r5-inline-name,sessioncold')]
    [TestCase('r5-inline-name sessionwarm', 'r5-inline-name,sessionwarm')]
    [TestCase('r5-inline-name standalone', 'r5-inline-name,standalone')]
    [TestCase('r5-inline-size cold', 'r5-inline-size,cold')]
    [TestCase('r5-inline-size snapshot', 'r5-inline-size,snapshot')]
    [TestCase('r5-inline-size sessioncold', 'r5-inline-size,sessioncold')]
    [TestCase('r5-inline-size sessionwarm', 'r5-inline-size,sessionwarm')]
    [TestCase('r5-inline-size standalone', 'r5-inline-size,standalone')]
    [TestCase('r5-inline-indexed cold', 'r5-inline-indexed,cold')]
    [TestCase('r5-inline-indexed snapshot', 'r5-inline-indexed,snapshot')]
    [TestCase('r5-inline-indexed sessioncold', 'r5-inline-indexed,sessioncold')]
    [TestCase('r5-inline-indexed sessionwarm', 'r5-inline-indexed,sessionwarm')]
    [TestCase('r5-inline-indexed standalone', 'r5-inline-indexed,standalone')]
    [TestCase('r5-multi-name cold', 'r5-multi-name,cold')]
    [TestCase('r5-multi-name snapshot', 'r5-multi-name,snapshot')]
    [TestCase('r5-multi-name sessioncold', 'r5-multi-name,sessioncold')]
    [TestCase('r5-multi-name sessionwarm', 'r5-multi-name,sessionwarm')]
    [TestCase('r5-multi-name standalone', 'r5-multi-name,standalone')]
    [TestCase('r5-multi-size cold', 'r5-multi-size,cold')]
    [TestCase('r5-multi-size snapshot', 'r5-multi-size,snapshot')]
    [TestCase('r5-multi-size sessioncold', 'r5-multi-size,sessioncold')]
    [TestCase('r5-multi-size sessionwarm', 'r5-multi-size,sessionwarm')]
    [TestCase('r5-multi-size standalone', 'r5-multi-size,standalone')]
    [TestCase('r5-multi-indexed cold', 'r5-multi-indexed,cold')]
    [TestCase('r5-multi-indexed snapshot', 'r5-multi-indexed,snapshot')]
    [TestCase('r5-multi-indexed sessioncold', 'r5-multi-indexed,sessioncold')]
    [TestCase('r5-multi-indexed sessionwarm', 'r5-multi-indexed,sessionwarm')]
    [TestCase('r5-multi-indexed standalone', 'r5-multi-indexed,standalone')]
    [TestCase('r5-comment-name cold', 'r5-comment-name,cold')]
    [TestCase('r5-comment-name snapshot', 'r5-comment-name,snapshot')]
    [TestCase('r5-comment-name sessioncold', 'r5-comment-name,sessioncold')]
    [TestCase('r5-comment-name sessionwarm', 'r5-comment-name,sessionwarm')]
    [TestCase('r5-comment-name standalone', 'r5-comment-name,standalone')]
    [TestCase('r5-comment-size cold', 'r5-comment-size,cold')]
    [TestCase('r5-comment-size snapshot', 'r5-comment-size,snapshot')]
    [TestCase('r5-comment-size sessioncold', 'r5-comment-size,sessioncold')]
    [TestCase('r5-comment-size sessionwarm', 'r5-comment-size,sessionwarm')]
    [TestCase('r5-comment-size standalone', 'r5-comment-size,standalone')]
    [TestCase('r5-comment-indexed cold', 'r5-comment-indexed,cold')]
    [TestCase('r5-comment-indexed snapshot', 'r5-comment-indexed,snapshot')]
    [TestCase('r5-comment-indexed sessioncold', 'r5-comment-indexed,sessioncold')]
    [TestCase('r5-comment-indexed sessionwarm', 'r5-comment-indexed,sessionwarm')]
    [TestCase('r5-comment-indexed standalone', 'r5-comment-indexed,standalone')]
    [TestCase('r5-newline-name cold', 'r5-newline-name,cold')]
    [TestCase('r5-newline-name snapshot', 'r5-newline-name,snapshot')]
    [TestCase('r5-newline-name sessioncold', 'r5-newline-name,sessioncold')]
    [TestCase('r5-newline-name sessionwarm', 'r5-newline-name,sessionwarm')]
    [TestCase('r5-newline-name standalone', 'r5-newline-name,standalone')]
    [TestCase('r5-newline-size cold', 'r5-newline-size,cold')]
    [TestCase('r5-newline-size snapshot', 'r5-newline-size,snapshot')]
    [TestCase('r5-newline-size sessioncold', 'r5-newline-size,sessioncold')]
    [TestCase('r5-newline-size sessionwarm', 'r5-newline-size,sessionwarm')]
    [TestCase('r5-newline-size standalone', 'r5-newline-size,standalone')]
    [TestCase('r5-newline-indexed cold', 'r5-newline-indexed,cold')]
    [TestCase('r5-newline-indexed snapshot', 'r5-newline-indexed,snapshot')]
    [TestCase('r5-newline-indexed sessioncold', 'r5-newline-indexed,sessioncold')]
    [TestCase('r5-newline-indexed sessionwarm', 'r5-newline-indexed,sessionwarm')]
    [TestCase('r5-newline-indexed standalone', 'r5-newline-indexed,standalone')]
    [TestCase('r5-chain-first-name cold', 'r5-chain-first-name,cold')]
    [TestCase('r5-chain-first-name snapshot', 'r5-chain-first-name,snapshot')]
    [TestCase('r5-chain-first-name sessioncold', 'r5-chain-first-name,sessioncold')]
    [TestCase('r5-chain-first-name sessionwarm', 'r5-chain-first-name,sessionwarm')]
    [TestCase('r5-chain-first-name standalone', 'r5-chain-first-name,standalone')]
    [TestCase('r5-chain-first-size cold', 'r5-chain-first-size,cold')]
    [TestCase('r5-chain-first-size snapshot', 'r5-chain-first-size,snapshot')]
    [TestCase('r5-chain-first-size sessioncold', 'r5-chain-first-size,sessioncold')]
    [TestCase('r5-chain-first-size sessionwarm', 'r5-chain-first-size,sessionwarm')]
    [TestCase('r5-chain-first-size standalone', 'r5-chain-first-size,standalone')]
    [TestCase('r5-chain-first-indexed cold', 'r5-chain-first-indexed,cold')]
    [TestCase('r5-chain-first-indexed snapshot', 'r5-chain-first-indexed,snapshot')]
    [TestCase('r5-chain-first-indexed sessioncold', 'r5-chain-first-indexed,sessioncold')]
    [TestCase('r5-chain-first-indexed sessionwarm', 'r5-chain-first-indexed,sessionwarm')]
    [TestCase('r5-chain-first-indexed standalone', 'r5-chain-first-indexed,standalone')]
    [TestCase('r5-chain-second-name cold', 'r5-chain-second-name,cold')]
    [TestCase('r5-chain-second-name snapshot', 'r5-chain-second-name,snapshot')]
    [TestCase('r5-chain-second-name sessioncold', 'r5-chain-second-name,sessioncold')]
    [TestCase('r5-chain-second-name sessionwarm', 'r5-chain-second-name,sessionwarm')]
    [TestCase('r5-chain-second-name standalone', 'r5-chain-second-name,standalone')]
    [TestCase('r5-chain-second-size cold', 'r5-chain-second-size,cold')]
    [TestCase('r5-chain-second-size snapshot', 'r5-chain-second-size,snapshot')]
    [TestCase('r5-chain-second-size sessioncold', 'r5-chain-second-size,sessioncold')]
    [TestCase('r5-chain-second-size sessionwarm', 'r5-chain-second-size,sessionwarm')]
    [TestCase('r5-chain-second-size standalone', 'r5-chain-second-size,standalone')]
    [TestCase('r5-chain-second-indexed cold', 'r5-chain-second-indexed,cold')]
    [TestCase('r5-chain-second-indexed snapshot', 'r5-chain-second-indexed,snapshot')]
    [TestCase('r5-chain-second-indexed sessioncold', 'r5-chain-second-indexed,sessioncold')]
    [TestCase('r5-chain-second-indexed sessionwarm', 'r5-chain-second-indexed,sessionwarm')]
    [TestCase('r5-chain-second-indexed standalone', 'r5-chain-second-indexed,standalone')]
    [TestCase('r5-nested-block cold', 'r5-nested-block,cold')]
    [TestCase('r5-nested-block snapshot', 'r5-nested-block,snapshot')]
    [TestCase('r5-nested-block sessioncold', 'r5-nested-block,sessioncold')]
    [TestCase('r5-nested-block sessionwarm', 'r5-nested-block,sessionwarm')]
    [TestCase('r5-nested-block standalone', 'r5-nested-block,standalone')]
    [TestCase('r5-nested-single cold', 'r5-nested-single,cold')]
    [TestCase('r5-nested-single snapshot', 'r5-nested-single,snapshot')]
    [TestCase('r5-nested-single sessioncold', 'r5-nested-single,sessioncold')]
    [TestCase('r5-nested-single sessionwarm', 'r5-nested-single,sessionwarm')]
    [TestCase('r5-nested-single standalone', 'r5-nested-single,standalone')]
    [TestCase('r5-nested-weak-strong cold', 'r5-nested-weak-strong,cold')]
    [TestCase('r5-nested-weak-strong snapshot', 'r5-nested-weak-strong,snapshot')]
    [TestCase('r5-nested-weak-strong sessioncold', 'r5-nested-weak-strong,sessioncold')]
    [TestCase('r5-nested-weak-strong sessionwarm', 'r5-nested-weak-strong,sessionwarm')]
    [TestCase('r5-nested-weak-strong standalone', 'r5-nested-weak-strong,standalone')]
    [TestCase('r5-nested-repeat cold', 'r5-nested-repeat,cold')]
    [TestCase('r5-nested-repeat snapshot', 'r5-nested-repeat,snapshot')]
    [TestCase('r5-nested-repeat sessioncold', 'r5-nested-repeat,sessioncold')]
    [TestCase('r5-nested-repeat sessionwarm', 'r5-nested-repeat,sessionwarm')]
    [TestCase('r5-nested-repeat standalone', 'r5-nested-repeat,standalone')]
    [TestCase('r4-x1-strong-excludeattr cold', 'r4-x1-strong-excludeattr,cold')]
    [TestCase('r4-x1-strong-excludeattr snapshot', 'r4-x1-strong-excludeattr,snapshot')]
    [TestCase('r4-x1-strong-excludeattr sessioncold', 'r4-x1-strong-excludeattr,sessioncold')]
    [TestCase('r4-x1-strong-excludeattr sessionwarm', 'r4-x1-strong-excludeattr,sessionwarm')]
    [TestCase('r4-x1-strong-excludeattr standalone', 'r4-x1-strong-excludeattr,standalone')]
    [TestCase('r4-x3-weak-of-strong-excl cold', 'r4-x3-weak-of-strong-excl,cold')]
    [TestCase('r4-x3-weak-of-strong-excl snapshot', 'r4-x3-weak-of-strong-excl,snapshot')]
    [TestCase('r4-x3-weak-of-strong-excl sessioncold', 'r4-x3-weak-of-strong-excl,sessioncold')]
    [TestCase('r4-x3-weak-of-strong-excl sessionwarm', 'r4-x3-weak-of-strong-excl,sessionwarm')]
    [TestCase('r4-x3-weak-of-strong-excl standalone', 'r4-x3-weak-of-strong-excl,standalone')]
    [TestCase('r4-x7-strong-name-plain cold', 'r4-x7-strong-name-plain,cold')]
    [TestCase('r4-x7-strong-name-plain snapshot', 'r4-x7-strong-name-plain,snapshot')]
    [TestCase('r4-x7-strong-name-plain sessioncold', 'r4-x7-strong-name-plain,sessioncold')]
    [TestCase('r4-x7-strong-name-plain sessionwarm', 'r4-x7-strong-name-plain,sessionwarm')]
    [TestCase('r4-x7-strong-name-plain standalone', 'r4-x7-strong-name-plain,standalone')]
    [TestCase('r4-x8-strong-size-plain cold', 'r4-x8-strong-size-plain,cold')]
    [TestCase('r4-x8-strong-size-plain snapshot', 'r4-x8-strong-size-plain,snapshot')]
    [TestCase('r4-x8-strong-size-plain sessioncold', 'r4-x8-strong-size-plain,sessioncold')]
    [TestCase('r4-x8-strong-size-plain sessionwarm', 'r4-x8-strong-size-plain,sessionwarm')]
    [TestCase('r4-x8-strong-size-plain standalone', 'r4-x8-strong-size-plain,standalone')]
    [TestCase('r4-x9-weak-of-strong-name cold', 'r4-x9-weak-of-strong-name,cold')]
    [TestCase('r4-x9-weak-of-strong-name snapshot', 'r4-x9-weak-of-strong-name,snapshot')]
    [TestCase('r4-x9-weak-of-strong-name sessioncold', 'r4-x9-weak-of-strong-name,sessioncold')]
    [TestCase('r4-x9-weak-of-strong-name sessionwarm', 'r4-x9-weak-of-strong-name,sessionwarm')]
    [TestCase('r4-x9-weak-of-strong-name standalone', 'r4-x9-weak-of-strong-name,standalone')]
    [TestCase('r4-weak-name-plain cold', 'r4-weak-name-plain,cold')]
    [TestCase('r4-weak-name-plain snapshot', 'r4-weak-name-plain,snapshot')]
    [TestCase('r4-weak-name-plain sessioncold', 'r4-weak-name-plain,sessioncold')]
    [TestCase('r4-weak-name-plain sessionwarm', 'r4-weak-name-plain,sessionwarm')]
    [TestCase('r4-weak-name-plain standalone', 'r4-weak-name-plain,standalone')]
    [TestCase('r4-weak-size-plain cold', 'r4-weak-size-plain,cold')]
    [TestCase('r4-weak-size-plain snapshot', 'r4-weak-size-plain,snapshot')]
    [TestCase('r4-weak-size-plain sessioncold', 'r4-weak-size-plain,sessioncold')]
    [TestCase('r4-weak-size-plain sessionwarm', 'r4-weak-size-plain,sessionwarm')]
    [TestCase('r4-weak-size-plain standalone', 'r4-weak-size-plain,standalone')]
    [TestCase('rtl-weak-chain-homonym cold', 'rtl-weak-chain-homonym,cold')]
    [TestCase('rtl-weak-chain-homonym snapshot', 'rtl-weak-chain-homonym,snapshot')]
    [TestCase('rtl-weak-chain-homonym sessioncold', 'rtl-weak-chain-homonym,sessioncold')]
    [TestCase('rtl-weak-chain-homonym sessionwarm', 'rtl-weak-chain-homonym,sessionwarm')]
    [TestCase('rtl-weak-chain-homonym standalone', 'rtl-weak-chain-homonym,standalone')]
    [TestCase('rtl-strong-homonym cold', 'rtl-strong-homonym,cold')]
    [TestCase('rtl-strong-homonym snapshot', 'rtl-strong-homonym,snapshot')]
    [TestCase('rtl-strong-homonym sessioncold', 'rtl-strong-homonym,sessioncold')]
    [TestCase('rtl-strong-homonym sessionwarm', 'rtl-strong-homonym,sessionwarm')]
    [TestCase('rtl-strong-homonym standalone', 'rtl-strong-homonym,standalone')]
    [TestCase('rtl-weak-homonym cold', 'rtl-weak-homonym,cold')]
    [TestCase('rtl-weak-homonym snapshot', 'rtl-weak-homonym,snapshot')]
    [TestCase('rtl-weak-homonym sessioncold', 'rtl-weak-homonym,sessioncold')]
    [TestCase('rtl-weak-homonym sessionwarm', 'rtl-weak-homonym,sessionwarm')]
    [TestCase('rtl-weak-homonym standalone', 'rtl-weak-homonym,standalone')]
    [TestCase('opus-e7-forward-nested-strong cold', 'opus-e7-forward-nested-strong,cold')]
    [TestCase('opus-e7-forward-nested-strong snapshot', 'opus-e7-forward-nested-strong,snapshot')]
    [TestCase('opus-e7-forward-nested-strong sessioncold', 'opus-e7-forward-nested-strong,sessioncold')]
    [TestCase('opus-e7-forward-nested-strong sessionwarm', 'opus-e7-forward-nested-strong,sessionwarm')]
    [TestCase('opus-e7-forward-nested-strong standalone', 'opus-e7-forward-nested-strong,standalone')]
    [TestCase('opus-e14-forward-two-level-strong cold', 'opus-e14-forward-two-level-strong,cold')]
    [TestCase('opus-e14-forward-two-level-strong snapshot', 'opus-e14-forward-two-level-strong,snapshot')]
    [TestCase('opus-e14-forward-two-level-strong sessioncold', 'opus-e14-forward-two-level-strong,sessioncold')]
    [TestCase('opus-e14-forward-two-level-strong sessionwarm', 'opus-e14-forward-two-level-strong,sessionwarm')]
    [TestCase('opus-e14-forward-two-level-strong standalone', 'opus-e14-forward-two-level-strong,standalone')]
    [TestCase('opus-h1-field-array-s cold', 'opus-h1-field-array-s,cold')]
    [TestCase('opus-h1-field-array-s snapshot', 'opus-h1-field-array-s,snapshot')]
    [TestCase('opus-h1-field-array-s sessioncold', 'opus-h1-field-array-s,sessioncold')]
    [TestCase('opus-h1-field-array-s sessionwarm', 'opus-h1-field-array-s,sessionwarm')]
    [TestCase('opus-h1-field-array-s standalone', 'opus-h1-field-array-s,standalone')]
    [TestCase('opus-h2-dotted-field-s cold', 'opus-h2-dotted-field-s,cold')]
    [TestCase('opus-h2-dotted-field-s snapshot', 'opus-h2-dotted-field-s,snapshot')]
    [TestCase('opus-h2-dotted-field-s sessioncold', 'opus-h2-dotted-field-s,sessioncold')]
    [TestCase('opus-h2-dotted-field-s sessionwarm', 'opus-h2-dotted-field-s,sessionwarm')]
    [TestCase('opus-h2-dotted-field-s standalone', 'opus-h2-dotted-field-s,standalone')]
    [TestCase('opus-h3-dotted-write-s cold', 'opus-h3-dotted-write-s,cold')]
    [TestCase('opus-h3-dotted-write-s snapshot', 'opus-h3-dotted-write-s,snapshot')]
    [TestCase('opus-h3-dotted-write-s sessioncold', 'opus-h3-dotted-write-s,sessioncold')]
    [TestCase('opus-h3-dotted-write-s sessionwarm', 'opus-h3-dotted-write-s,sessionwarm')]
    [TestCase('opus-h3-dotted-write-s standalone', 'opus-h3-dotted-write-s,standalone')]
    [TestCase('opus-c5-indexed-default-s2 cold', 'opus-c5-indexed-default-s2,cold')]
    [TestCase('opus-c5-indexed-default-s2 snapshot', 'opus-c5-indexed-default-s2,snapshot')]
    [TestCase('opus-c5-indexed-default-s2 sessioncold', 'opus-c5-indexed-default-s2,sessioncold')]
    [TestCase('opus-c5-indexed-default-s2 sessionwarm', 'opus-c5-indexed-default-s2,sessionwarm')]
    [TestCase('opus-c5-indexed-default-s2 standalone', 'opus-c5-indexed-default-s2,standalone')]
    [TestCase('opus-c1-args-members-s2 cold', 'opus-c1-args-members-s2,cold')]
    [TestCase('opus-c1-args-members-s2 snapshot', 'opus-c1-args-members-s2,snapshot')]
    [TestCase('opus-c1-args-members-s2 sessioncold', 'opus-c1-args-members-s2,sessioncold')]
    [TestCase('opus-c1-args-members-s2 sessionwarm', 'opus-c1-args-members-s2,sessionwarm')]
    [TestCase('opus-c1-args-members-s2 standalone', 'opus-c1-args-members-s2,standalone')]
    [TestCase('opus-f5-strong-chain-overload-call cold', 'opus-f5-strong-chain-overload-call,cold')]
    [TestCase('opus-f5-strong-chain-overload-call snapshot', 'opus-f5-strong-chain-overload-call,snapshot')]
    [TestCase('opus-f5-strong-chain-overload-call sessioncold', 'opus-f5-strong-chain-overload-call,sessioncold')]
    [TestCase('opus-f5-strong-chain-overload-call sessionwarm', 'opus-f5-strong-chain-overload-call,sessionwarm')]
    [TestCase('opus-f5-strong-chain-overload-call standalone', 'opus-f5-strong-chain-overload-call,standalone')]
    [TestCase('sol-forward-captured-strong cold', 'sol-forward-captured-strong,cold')]
    [TestCase('sol-forward-captured-strong snapshot', 'sol-forward-captured-strong,snapshot')]
    [TestCase('sol-forward-captured-strong sessioncold', 'sol-forward-captured-strong,sessioncold')]
    [TestCase('sol-forward-captured-strong sessionwarm', 'sol-forward-captured-strong,sessionwarm')]
    [TestCase('sol-forward-captured-strong standalone', 'sol-forward-captured-strong,standalone')]
    [TestCase('sol-forward-late-strong cold', 'sol-forward-late-strong,cold')]
    [TestCase('sol-forward-late-strong snapshot', 'sol-forward-late-strong,snapshot')]
    [TestCase('sol-forward-late-strong sessioncold', 'sol-forward-late-strong,sessioncold')]
    [TestCase('sol-forward-late-strong sessionwarm', 'sol-forward-late-strong,sessionwarm')]
    [TestCase('sol-forward-late-strong standalone', 'sol-forward-late-strong,standalone')]
    [TestCase('sol-clean-strong-overload cold', 'sol-clean-strong-overload,cold')]
    [TestCase('sol-clean-strong-overload snapshot', 'sol-clean-strong-overload,snapshot')]
    [TestCase('sol-clean-strong-overload sessioncold', 'sol-clean-strong-overload,sessioncold')]
    [TestCase('sol-clean-strong-overload sessionwarm', 'sol-clean-strong-overload,sessionwarm')]
    [TestCase('sol-clean-strong-overload standalone', 'sol-clean-strong-overload,standalone')]
    [TestCase('sol-getter-property-call-strong cold', 'sol-getter-property-call-strong,cold')]
    [TestCase('sol-getter-property-call-strong snapshot', 'sol-getter-property-call-strong,snapshot')]
    [TestCase('sol-getter-property-call-strong sessioncold', 'sol-getter-property-call-strong,sessioncold')]
    [TestCase('sol-getter-property-call-strong sessionwarm', 'sol-getter-property-call-strong,sessionwarm')]
    [TestCase('sol-getter-property-call-strong standalone', 'sol-getter-property-call-strong,standalone')]
    [TestCase('sol-clean-strong-indexed-read cold', 'sol-clean-strong-indexed-read,cold')]
    [TestCase('sol-clean-strong-indexed-read snapshot', 'sol-clean-strong-indexed-read,snapshot')]
    [TestCase('sol-clean-strong-indexed-read sessioncold', 'sol-clean-strong-indexed-read,sessioncold')]
    [TestCase('sol-clean-strong-indexed-read sessionwarm', 'sol-clean-strong-indexed-read,sessionwarm')]
    [TestCase('sol-clean-strong-indexed-read standalone', 'sol-clean-strong-indexed-read,standalone')]
    [TestCase('sol-clean-strong-indexed-write cold', 'sol-clean-strong-indexed-write,cold')]
    [TestCase('sol-clean-strong-indexed-write snapshot', 'sol-clean-strong-indexed-write,snapshot')]
    [TestCase('sol-clean-strong-indexed-write sessioncold', 'sol-clean-strong-indexed-write,sessioncold')]
    [TestCase('sol-clean-strong-indexed-write sessionwarm', 'sol-clean-strong-indexed-write,sessionwarm')]
    [TestCase('sol-clean-strong-indexed-write standalone', 'sol-clean-strong-indexed-write,standalone')]
    [TestCase('sol-clean-generic-indexed-write cold', 'sol-clean-generic-indexed-write,cold')]
    [TestCase('sol-clean-generic-indexed-write snapshot', 'sol-clean-generic-indexed-write,snapshot')]
    [TestCase('sol-clean-generic-indexed-write sessioncold', 'sol-clean-generic-indexed-write,sessioncold')]
    [TestCase('sol-clean-generic-indexed-write sessionwarm', 'sol-clean-generic-indexed-write,sessionwarm')]
    [TestCase('sol-clean-generic-indexed-write standalone', 'sol-clean-generic-indexed-write,standalone')]
    [TestCase('control-h1-field-array-w cold', 'control-h1-field-array-w,cold')]
    [TestCase('control-h1-field-array-w snapshot', 'control-h1-field-array-w,snapshot')]
    [TestCase('control-h1-field-array-w sessioncold', 'control-h1-field-array-w,sessioncold')]
    [TestCase('control-h1-field-array-w sessionwarm', 'control-h1-field-array-w,sessionwarm')]
    [TestCase('control-h1-field-array-w standalone', 'control-h1-field-array-w,standalone')]
    [TestCase('control-h2-dotted-field-w cold', 'control-h2-dotted-field-w,cold')]
    [TestCase('control-h2-dotted-field-w snapshot', 'control-h2-dotted-field-w,snapshot')]
    [TestCase('control-h2-dotted-field-w sessioncold', 'control-h2-dotted-field-w,sessioncold')]
    [TestCase('control-h2-dotted-field-w sessionwarm', 'control-h2-dotted-field-w,sessionwarm')]
    [TestCase('control-h2-dotted-field-w standalone', 'control-h2-dotted-field-w,standalone')]
    [TestCase('control-h3-dotted-write-w cold', 'control-h3-dotted-write-w,cold')]
    [TestCase('control-h3-dotted-write-w snapshot', 'control-h3-dotted-write-w,snapshot')]
    [TestCase('control-h3-dotted-write-w sessioncold', 'control-h3-dotted-write-w,sessioncold')]
    [TestCase('control-h3-dotted-write-w sessionwarm', 'control-h3-dotted-write-w,sessionwarm')]
    [TestCase('control-h3-dotted-write-w standalone', 'control-h3-dotted-write-w,standalone')]
    [TestCase('control-c5-indexed-default-w2 cold', 'control-c5-indexed-default-w2,cold')]
    [TestCase('control-c5-indexed-default-w2 snapshot', 'control-c5-indexed-default-w2,snapshot')]
    [TestCase('control-c5-indexed-default-w2 sessioncold', 'control-c5-indexed-default-w2,sessioncold')]
    [TestCase('control-c5-indexed-default-w2 sessionwarm', 'control-c5-indexed-default-w2,sessionwarm')]
    [TestCase('control-c5-indexed-default-w2 standalone', 'control-c5-indexed-default-w2,standalone')]
    [TestCase('control-c1-args-members-w2 cold', 'control-c1-args-members-w2,cold')]
    [TestCase('control-c1-args-members-w2 snapshot', 'control-c1-args-members-w2,snapshot')]
    [TestCase('control-c1-args-members-w2 sessioncold', 'control-c1-args-members-w2,sessioncold')]
    [TestCase('control-c1-args-members-w2 sessionwarm', 'control-c1-args-members-w2,sessionwarm')]
    [TestCase('control-c1-args-members-w2 standalone', 'control-c1-args-members-w2,standalone')]
    [TestCase('control-clean-weak-overload cold', 'control-clean-weak-overload,cold')]
    [TestCase('control-clean-weak-overload snapshot', 'control-clean-weak-overload,snapshot')]
    [TestCase('control-clean-weak-overload sessioncold', 'control-clean-weak-overload,sessioncold')]
    [TestCase('control-clean-weak-overload sessionwarm', 'control-clean-weak-overload,sessionwarm')]
    [TestCase('control-clean-weak-overload standalone', 'control-clean-weak-overload,standalone')]
    [TestCase('control-clean-plain-overload cold', 'control-clean-plain-overload,cold')]
    [TestCase('control-clean-plain-overload snapshot', 'control-clean-plain-overload,snapshot')]
    [TestCase('control-clean-plain-overload sessioncold', 'control-clean-plain-overload,sessioncold')]
    [TestCase('control-clean-plain-overload sessionwarm', 'control-clean-plain-overload,sessionwarm')]
    [TestCase('control-clean-plain-overload standalone', 'control-clean-plain-overload,standalone')]
    [TestCase('control-getter-property-call-weak cold', 'control-getter-property-call-weak,cold')]
    [TestCase('control-getter-property-call-weak snapshot', 'control-getter-property-call-weak,snapshot')]
    [TestCase('control-getter-property-call-weak sessioncold', 'control-getter-property-call-weak,sessioncold')]
    [TestCase('control-getter-property-call-weak sessionwarm', 'control-getter-property-call-weak,sessionwarm')]
    [TestCase('control-getter-property-call-weak standalone', 'control-getter-property-call-weak,standalone')]
    [TestCase('control-getter-property-call-plain cold', 'control-getter-property-call-plain,cold')]
    [TestCase('control-getter-property-call-plain snapshot', 'control-getter-property-call-plain,snapshot')]
    [TestCase('control-getter-property-call-plain sessioncold', 'control-getter-property-call-plain,sessioncold')]
    [TestCase('control-getter-property-call-plain sessionwarm', 'control-getter-property-call-plain,sessionwarm')]
    [TestCase('control-getter-property-call-plain standalone', 'control-getter-property-call-plain,standalone')]
    [TestCase('control-clean-weak-indexed-read cold', 'control-clean-weak-indexed-read,cold')]
    [TestCase('control-clean-weak-indexed-read snapshot', 'control-clean-weak-indexed-read,snapshot')]
    [TestCase('control-clean-weak-indexed-read sessioncold', 'control-clean-weak-indexed-read,sessioncold')]
    [TestCase('control-clean-weak-indexed-read sessionwarm', 'control-clean-weak-indexed-read,sessionwarm')]
    [TestCase('control-clean-weak-indexed-read standalone', 'control-clean-weak-indexed-read,standalone')]
    [TestCase('control-clean-plain-indexed-read cold', 'control-clean-plain-indexed-read,cold')]
    [TestCase('control-clean-plain-indexed-read snapshot', 'control-clean-plain-indexed-read,snapshot')]
    [TestCase('control-clean-plain-indexed-read sessioncold', 'control-clean-plain-indexed-read,sessioncold')]
    [TestCase('control-clean-plain-indexed-read sessionwarm', 'control-clean-plain-indexed-read,sessionwarm')]
    [TestCase('control-clean-plain-indexed-read standalone', 'control-clean-plain-indexed-read,standalone')]
    [TestCase('control-clean-weak-indexed-write cold', 'control-clean-weak-indexed-write,cold')]
    [TestCase('control-clean-weak-indexed-write snapshot', 'control-clean-weak-indexed-write,snapshot')]
    [TestCase('control-clean-weak-indexed-write sessioncold', 'control-clean-weak-indexed-write,sessioncold')]
    [TestCase('control-clean-weak-indexed-write sessionwarm', 'control-clean-weak-indexed-write,sessionwarm')]
    [TestCase('control-clean-weak-indexed-write standalone', 'control-clean-weak-indexed-write,standalone')]
    [TestCase('control-clean-plain-indexed-write cold', 'control-clean-plain-indexed-write,cold')]
    [TestCase('control-clean-plain-indexed-write snapshot', 'control-clean-plain-indexed-write,snapshot')]
    [TestCase('control-clean-plain-indexed-write sessioncold', 'control-clean-plain-indexed-write,sessioncold')]
    [TestCase('control-clean-plain-indexed-write sessionwarm', 'control-clean-plain-indexed-write,sessionwarm')]
    [TestCase('control-clean-plain-indexed-write standalone', 'control-clean-plain-indexed-write,standalone')]
    [TestCase('control-opus-e7-forward-nested-strong-weak cold', 'control-opus-e7-forward-nested-strong-weak,cold')]
    [TestCase('control-opus-e7-forward-nested-strong-weak snapshot', 'control-opus-e7-forward-nested-strong-weak,snapshot')]
    [TestCase('control-opus-e7-forward-nested-strong-weak sessioncold', 'control-opus-e7-forward-nested-strong-weak,sessioncold')]
    [TestCase('control-opus-e7-forward-nested-strong-weak sessionwarm warm-unreachable DS743', 'control-opus-e7-forward-nested-strong-weak,sessionwarm')]
    [TestCase('control-opus-e7-forward-nested-strong-weak standalone warm-unreachable DS743', 'control-opus-e7-forward-nested-strong-weak,standalone')]
    [TestCase('control-opus-e7-forward-nested-strong-plain cold', 'control-opus-e7-forward-nested-strong-plain,cold')]
    [TestCase('control-opus-e7-forward-nested-strong-plain snapshot', 'control-opus-e7-forward-nested-strong-plain,snapshot')]
    [TestCase('control-opus-e7-forward-nested-strong-plain sessioncold', 'control-opus-e7-forward-nested-strong-plain,sessioncold')]
    [TestCase('control-opus-e7-forward-nested-strong-plain sessionwarm', 'control-opus-e7-forward-nested-strong-plain,sessionwarm')]
    [TestCase('control-opus-e7-forward-nested-strong-plain standalone', 'control-opus-e7-forward-nested-strong-plain,standalone')]
    [TestCase('control-opus-e14-forward-two-level-strong-weak cold', 'control-opus-e14-forward-two-level-strong-weak,cold')]
    [TestCase('control-opus-e14-forward-two-level-strong-weak snapshot', 'control-opus-e14-forward-two-level-strong-weak,snapshot')]
    [TestCase('control-opus-e14-forward-two-level-strong-weak sessioncold', 'control-opus-e14-forward-two-level-strong-weak,sessioncold')]
    [TestCase('control-opus-e14-forward-two-level-strong-weak sessionwarm warm-unreachable DS743', 'control-opus-e14-forward-two-level-strong-weak,sessionwarm')]
    [TestCase('control-opus-e14-forward-two-level-strong-weak standalone warm-unreachable DS743', 'control-opus-e14-forward-two-level-strong-weak,standalone')]
    [TestCase('control-opus-e14-forward-two-level-strong-plain cold', 'control-opus-e14-forward-two-level-strong-plain,cold')]
    [TestCase('control-opus-e14-forward-two-level-strong-plain snapshot', 'control-opus-e14-forward-two-level-strong-plain,snapshot')]
    [TestCase('control-opus-e14-forward-two-level-strong-plain sessioncold', 'control-opus-e14-forward-two-level-strong-plain,sessioncold')]
    [TestCase('control-opus-e14-forward-two-level-strong-plain sessionwarm', 'control-opus-e14-forward-two-level-strong-plain,sessionwarm')]
    [TestCase('control-opus-e14-forward-two-level-strong-plain standalone', 'control-opus-e14-forward-two-level-strong-plain,standalone')]
    [TestCase('control-h1-field-array-w-plain cold', 'control-h1-field-array-w-plain,cold')]
    [TestCase('control-h1-field-array-w-plain snapshot', 'control-h1-field-array-w-plain,snapshot')]
    [TestCase('control-h1-field-array-w-plain sessioncold', 'control-h1-field-array-w-plain,sessioncold')]
    [TestCase('control-h1-field-array-w-plain sessionwarm', 'control-h1-field-array-w-plain,sessionwarm')]
    [TestCase('control-h1-field-array-w-plain standalone', 'control-h1-field-array-w-plain,standalone')]
    [TestCase('control-h2-dotted-field-w-plain cold', 'control-h2-dotted-field-w-plain,cold')]
    [TestCase('control-h2-dotted-field-w-plain snapshot', 'control-h2-dotted-field-w-plain,snapshot')]
    [TestCase('control-h2-dotted-field-w-plain sessioncold', 'control-h2-dotted-field-w-plain,sessioncold')]
    [TestCase('control-h2-dotted-field-w-plain sessionwarm', 'control-h2-dotted-field-w-plain,sessionwarm')]
    [TestCase('control-h2-dotted-field-w-plain standalone', 'control-h2-dotted-field-w-plain,standalone')]
    [TestCase('control-h3-dotted-write-w-plain cold', 'control-h3-dotted-write-w-plain,cold')]
    [TestCase('control-h3-dotted-write-w-plain snapshot', 'control-h3-dotted-write-w-plain,snapshot')]
    [TestCase('control-h3-dotted-write-w-plain sessioncold', 'control-h3-dotted-write-w-plain,sessioncold')]
    [TestCase('control-h3-dotted-write-w-plain sessionwarm', 'control-h3-dotted-write-w-plain,sessionwarm')]
    [TestCase('control-h3-dotted-write-w-plain standalone', 'control-h3-dotted-write-w-plain,standalone')]
    [TestCase('control-c5-indexed-default-w2-plain cold', 'control-c5-indexed-default-w2-plain,cold')]
    [TestCase('control-c5-indexed-default-w2-plain snapshot', 'control-c5-indexed-default-w2-plain,snapshot')]
    [TestCase('control-c5-indexed-default-w2-plain sessioncold', 'control-c5-indexed-default-w2-plain,sessioncold')]
    [TestCase('control-c5-indexed-default-w2-plain sessionwarm', 'control-c5-indexed-default-w2-plain,sessionwarm')]
    [TestCase('control-c5-indexed-default-w2-plain standalone', 'control-c5-indexed-default-w2-plain,standalone')]
    [TestCase('control-c1-args-members-w2-plain cold', 'control-c1-args-members-w2-plain,cold')]
    [TestCase('control-c1-args-members-w2-plain snapshot', 'control-c1-args-members-w2-plain,snapshot')]
    [TestCase('control-c1-args-members-w2-plain sessioncold', 'control-c1-args-members-w2-plain,sessioncold')]
    [TestCase('control-c1-args-members-w2-plain sessionwarm', 'control-c1-args-members-w2-plain,sessionwarm')]
    [TestCase('control-c1-args-members-w2-plain standalone', 'control-c1-args-members-w2-plain,standalone')]
    [TestCase('r6-strong cold', 'r6-strong,cold')]
    [TestCase('r6-strong snapshot', 'r6-strong,snapshot')]
    [TestCase('r6-strong sessioncold', 'r6-strong,sessioncold')]
    [TestCase('r6-strong sessionwarm', 'r6-strong,sessionwarm')]
    [TestCase('r6-strong standalone', 'r6-strong,standalone')]
    [TestCase('r6-control-plain-strong cold', 'r6-control-plain-strong,cold')]
    [TestCase('r6-control-plain-strong snapshot', 'r6-control-plain-strong,snapshot')]
    [TestCase('r6-control-plain-strong sessioncold', 'r6-control-plain-strong,sessioncold')]
    [TestCase('r6-control-plain-strong sessionwarm', 'r6-control-plain-strong,sessionwarm')]
    [TestCase('r6-control-plain-strong standalone', 'r6-control-plain-strong,standalone')]
    [TestCase('r6-control-weak-strong cold', 'r6-control-weak-strong,cold')]
    [TestCase('r6-control-weak-strong snapshot', 'r6-control-weak-strong,snapshot')]
    [TestCase('r6-control-weak-strong sessioncold', 'r6-control-weak-strong,sessioncold')]
    [TestCase('r6-control-weak-strong sessionwarm', 'r6-control-weak-strong,sessionwarm')]
    [TestCase('r6-control-weak-strong standalone', 'r6-control-weak-strong,standalone')]
    [TestCase('r6-function cold', 'r6-function,cold')]
    [TestCase('r6-function snapshot', 'r6-function,snapshot')]
    [TestCase('r6-function sessioncold', 'r6-function,sessioncold')]
    [TestCase('r6-function sessionwarm', 'r6-function,sessionwarm')]
    [TestCase('r6-function standalone', 'r6-function,standalone')]
    [TestCase('r6-control-plain-function cold', 'r6-control-plain-function,cold')]
    [TestCase('r6-control-plain-function snapshot', 'r6-control-plain-function,snapshot')]
    [TestCase('r6-control-plain-function sessioncold', 'r6-control-plain-function,sessioncold')]
    [TestCase('r6-control-plain-function sessionwarm', 'r6-control-plain-function,sessionwarm')]
    [TestCase('r6-control-plain-function standalone', 'r6-control-plain-function,standalone')]
    [TestCase('r6-control-weak-function cold', 'r6-control-weak-function,cold')]
    [TestCase('r6-control-weak-function snapshot', 'r6-control-weak-function,snapshot')]
    [TestCase('r6-control-weak-function sessioncold', 'r6-control-weak-function,sessioncold')]
    [TestCase('r6-control-weak-function sessionwarm', 'r6-control-weak-function,sessionwarm')]
    [TestCase('r6-control-weak-function standalone', 'r6-control-weak-function,standalone')]
    [TestCase('r6-nested cold', 'r6-nested,cold')]
    [TestCase('r6-nested snapshot', 'r6-nested,snapshot')]
    [TestCase('r6-nested sessioncold', 'r6-nested,sessioncold')]
    [TestCase('r6-nested sessionwarm', 'r6-nested,sessionwarm')]
    [TestCase('r6-nested standalone', 'r6-nested,standalone')]
    [TestCase('r6-control-plain-nested cold', 'r6-control-plain-nested,cold')]
    [TestCase('r6-control-plain-nested snapshot', 'r6-control-plain-nested,snapshot')]
    [TestCase('r6-control-plain-nested sessioncold', 'r6-control-plain-nested,sessioncold')]
    [TestCase('r6-control-plain-nested sessionwarm', 'r6-control-plain-nested,sessionwarm')]
    [TestCase('r6-control-plain-nested standalone', 'r6-control-plain-nested,standalone')]
    [TestCase('r6-control-weak-nested cold', 'r6-control-weak-nested,cold')]
    [TestCase('r6-control-weak-nested snapshot', 'r6-control-weak-nested,snapshot')]
    [TestCase('r6-control-weak-nested sessioncold', 'r6-control-weak-nested,sessioncold')]
    [TestCase('r6-control-weak-nested sessionwarm', 'r6-control-weak-nested,sessionwarm')]
    [TestCase('r6-control-weak-nested standalone', 'r6-control-weak-nested,standalone')]
    [TestCase('r6-weak-strong cold', 'r6-weak-strong,cold')]
    [TestCase('r6-weak-strong snapshot', 'r6-weak-strong,snapshot')]
    [TestCase('r6-weak-strong sessioncold', 'r6-weak-strong,sessioncold')]
    [TestCase('r6-weak-strong sessionwarm', 'r6-weak-strong,sessionwarm')]
    [TestCase('r6-weak-strong standalone', 'r6-weak-strong,standalone')]
    [TestCase('r6-control-plain-weak-strong cold', 'r6-control-plain-weak-strong,cold')]
    [TestCase('r6-control-plain-weak-strong snapshot', 'r6-control-plain-weak-strong,snapshot')]
    [TestCase('r6-control-plain-weak-strong sessioncold', 'r6-control-plain-weak-strong,sessioncold')]
    [TestCase('r6-control-plain-weak-strong sessionwarm', 'r6-control-plain-weak-strong,sessionwarm')]
    [TestCase('r6-control-plain-weak-strong standalone', 'r6-control-plain-weak-strong,standalone')]
    [TestCase('r6-control-weak-weak-strong cold', 'r6-control-weak-weak-strong,cold')]
    [TestCase('r6-control-weak-weak-strong snapshot', 'r6-control-weak-weak-strong,snapshot')]
    [TestCase('r6-control-weak-weak-strong sessioncold', 'r6-control-weak-weak-strong,sessioncold')]
    [TestCase('r6-control-weak-weak-strong sessionwarm', 'r6-control-weak-weak-strong,sessionwarm')]
    [TestCase('r6-control-weak-weak-strong standalone', 'r6-control-weak-weak-strong,standalone')]
    [TestCase('r6-other-unit cold', 'r6-other-unit,cold')]
    [TestCase('r6-other-unit snapshot', 'r6-other-unit,snapshot')]
    [TestCase('r6-other-unit sessioncold', 'r6-other-unit,sessioncold')]
    [TestCase('r6-other-unit sessionwarm', 'r6-other-unit,sessionwarm')]
    [TestCase('r6-other-unit standalone', 'r6-other-unit,standalone')]
    [TestCase('r6-control-plain-other-unit cold', 'r6-control-plain-other-unit,cold')]
    [TestCase('r6-control-plain-other-unit snapshot', 'r6-control-plain-other-unit,snapshot')]
    [TestCase('r6-control-plain-other-unit sessioncold', 'r6-control-plain-other-unit,sessioncold')]
    [TestCase('r6-control-plain-other-unit sessionwarm', 'r6-control-plain-other-unit,sessionwarm')]
    [TestCase('r6-control-plain-other-unit standalone', 'r6-control-plain-other-unit,standalone')]
    [TestCase('r6-control-weak-other-unit cold', 'r6-control-weak-other-unit,cold')]
    [TestCase('r6-control-weak-other-unit snapshot', 'r6-control-weak-other-unit,snapshot')]
    [TestCase('r6-control-weak-other-unit sessioncold', 'r6-control-weak-other-unit,sessioncold')]
    [TestCase('r6-control-weak-other-unit sessionwarm', 'r6-control-weak-other-unit,sessionwarm')]
    [TestCase('r6-control-weak-other-unit standalone', 'r6-control-weak-other-unit,standalone')]
    [TestCase('r6-inline-target cold', 'r6-inline-target,cold')]
    [TestCase('r6-inline-target snapshot', 'r6-inline-target,snapshot')]
    [TestCase('r6-inline-target sessioncold', 'r6-inline-target,sessioncold')]
    [TestCase('r6-inline-target sessionwarm', 'r6-inline-target,sessionwarm')]
    [TestCase('r6-inline-target standalone', 'r6-inline-target,standalone')]
    [TestCase('r6-control-plain-inline-target cold', 'r6-control-plain-inline-target,cold')]
    [TestCase('r6-control-plain-inline-target snapshot', 'r6-control-plain-inline-target,snapshot')]
    [TestCase('r6-control-plain-inline-target sessioncold', 'r6-control-plain-inline-target,sessioncold')]
    [TestCase('r6-control-plain-inline-target sessionwarm', 'r6-control-plain-inline-target,sessionwarm')]
    [TestCase('r6-control-plain-inline-target standalone', 'r6-control-plain-inline-target,standalone')]
    [TestCase('r6-control-weak-inline-target cold', 'r6-control-weak-inline-target,cold')]
    [TestCase('r6-control-weak-inline-target snapshot', 'r6-control-weak-inline-target,snapshot')]
    [TestCase('r6-control-weak-inline-target sessioncold', 'r6-control-weak-inline-target,sessioncold')]
    [TestCase('r6-control-weak-inline-target sessionwarm', 'r6-control-weak-inline-target,sessionwarm')]
    [TestCase('r6-control-weak-inline-target standalone', 'r6-control-weak-inline-target,standalone')]
    [TestCase('r6-control-parenthesized cold', 'r6-control-parenthesized,cold')]
    [TestCase('r6-control-parenthesized snapshot', 'r6-control-parenthesized,snapshot')]
    [TestCase('r6-control-parenthesized sessioncold', 'r6-control-parenthesized,sessioncold')]
    [TestCase('r6-control-parenthesized sessionwarm', 'r6-control-parenthesized,sessionwarm')]
    [TestCase('r6-control-parenthesized standalone', 'r6-control-parenthesized,standalone')]
    procedure AliasFallbackAndForwardScopes(const aShape, aMode: string);
    [Test]
    [TestCase('r5-nested-different cold', 'r5-nested-different,cold')]
    [TestCase('r5-nested-different snapshot', 'r5-nested-different,snapshot')]
    [TestCase('r5-nested-different sessioncold', 'r5-nested-different,sessioncold')]
    [TestCase('r5-nested-different sessionwarm', 'r5-nested-different,sessionwarm')]
    [TestCase('r5-nested-different standalone', 'r5-nested-different,standalone')]
    [TestCase('r5-nested-function cold', 'r5-nested-function,cold')]
    [TestCase('r5-nested-function snapshot', 'r5-nested-function,snapshot')]
    [TestCase('r5-nested-function sessioncold', 'r5-nested-function,sessioncold')]
    [TestCase('r5-nested-function sessionwarm', 'r5-nested-function,sessionwarm')]
    [TestCase('r5-nested-function standalone', 'r5-nested-function,standalone')]
    [Category('DS742M5')]
    procedure IdenticalReceiverExceptionNegativeControls(const aShape, aMode: string);



    [Category('DS741RMPV')]
    [TestCase('partial-forward-ancestor cold', 'partial-forward-ancestor,cold')]
    [TestCase('partial-forward-ancestor snapshot', 'partial-forward-ancestor,snapshot')]
    [TestCase('partial-forward-ancestor sessioncold', 'partial-forward-ancestor,sessioncold')]
    [TestCase('partial-forward-ancestor sessionwarm', 'partial-forward-ancestor,sessionwarm')]
    [TestCase('partial-forward-ancestor standalone', 'partial-forward-ancestor,standalone')]
    [TestCase('nested-forward-ancestor cold', 'nested-forward-ancestor,cold')]
    [TestCase('nested-forward-ancestor snapshot', 'nested-forward-ancestor,snapshot')]
    [TestCase('nested-forward-ancestor sessioncold', 'nested-forward-ancestor,sessioncold')]
    [TestCase('nested-forward-ancestor sessionwarm', 'nested-forward-ancestor,sessionwarm')]
    [TestCase('nested-forward-ancestor standalone', 'nested-forward-ancestor,standalone')]
    [TestCase('partial-cascade-forward-ancestor cold', 'partial-cascade-forward-ancestor,cold')]
    [TestCase('partial-cascade-forward-ancestor snapshot', 'partial-cascade-forward-ancestor,snapshot')]
    [TestCase('partial-cascade-forward-ancestor sessioncold', 'partial-cascade-forward-ancestor,sessioncold')]
    [TestCase('partial-cascade-forward-ancestor sessionwarm', 'partial-cascade-forward-ancestor,sessionwarm')]
    [TestCase('partial-cascade-forward-ancestor standalone', 'partial-cascade-forward-ancestor,standalone')]
    [TestCase('rmpv-compiling-anon-field cold', 'rmpv-compiling-anon-field,cold')]
    [TestCase('rmpv-compiling-anon-field snapshot', 'rmpv-compiling-anon-field,snapshot')]
    [TestCase('rmpv-compiling-anon-field sessioncold', 'rmpv-compiling-anon-field,sessioncold')]
    [TestCase('rmpv-compiling-anon-field sessionwarm', 'rmpv-compiling-anon-field,sessionwarm')]
    [TestCase('rmpv-compiling-anon-field standalone', 'rmpv-compiling-anon-field,standalone')]
    procedure AliasReceiverUnverifiedFamiliesRemainRefused(const aShape, aMode: string);


    [Test]
    [Category('DS731Persistence')]
    procedure ModelFreeLookupCannotProveValueAbsence;
    [Category('DS731Identity')]
    [TestCase('homonym-safe cold', 'homonym-safe,cold')]
    [TestCase('homonym-safe snapshot', 'homonym-safe,snapshot')]
    [TestCase('homonym-safe sessioncold', 'homonym-safe,sessioncold')]
    [TestCase('homonym-safe sessionwarm', 'homonym-safe,sessionwarm')]
    [TestCase('homonym-safe standalone', 'homonym-safe,standalone')]
    [TestCase('homonym-tag cold', 'homonym-tag,cold')]
    [TestCase('homonym-tag snapshot', 'homonym-tag,snapshot')]
    [TestCase('homonym-tag sessioncold', 'homonym-tag,sessioncold')]
    [TestCase('homonym-tag sessionwarm', 'homonym-tag,sessionwarm')]
    [TestCase('homonym-tag standalone', 'homonym-tag,standalone')]
    [TestCase('homonym-constant cold', 'homonym-constant,cold')]
    [TestCase('homonym-constant snapshot', 'homonym-constant,snapshot')]
    [TestCase('homonym-constant sessioncold', 'homonym-constant,sessioncold')]
    [TestCase('homonym-constant sessionwarm', 'homonym-constant,sessionwarm')]
    [TestCase('homonym-constant standalone', 'homonym-constant,standalone')]
    [TestCase('homonym-unverified cold', 'homonym-unverified,cold')]
    [TestCase('homonym-unverified snapshot', 'homonym-unverified,snapshot')]
    [TestCase('homonym-unverified sessioncold', 'homonym-unverified,sessioncold')]
    [TestCase('homonym-unverified sessionwarm', 'homonym-unverified,sessionwarm')]
    [TestCase('homonym-unverified standalone', 'homonym-unverified,standalone')]
    procedure ValueCoverageUsesReceiverIdentity(const aShape, aMode: string);
    [Category('DS731PartialReceiver')]
    [TestCase('partial-weak-global cold', 'partial-weak-global,cold')]
    [TestCase('partial-weak-global snapshot', 'partial-weak-global,snapshot')]
    [TestCase('partial-weak-global sessioncold', 'partial-weak-global,sessioncold')]
    [TestCase('partial-weak-global sessionwarm', 'partial-weak-global,sessionwarm')]
    [TestCase('partial-weak-global standalone', 'partial-weak-global,standalone')]
    [TestCase('partial-weak-noglobal cold', 'partial-weak-noglobal,cold')]
    [TestCase('partial-weak-noglobal snapshot', 'partial-weak-noglobal,snapshot')]
    [TestCase('partial-weak-noglobal sessioncold', 'partial-weak-noglobal,sessioncold')]
    [TestCase('partial-weak-noglobal sessionwarm', 'partial-weak-noglobal,sessionwarm')]
    [TestCase('partial-weak-noglobal standalone', 'partial-weak-noglobal,standalone')]
    [TestCase('partial-strong-global cold', 'partial-strong-global,cold')]
    [TestCase('partial-strong-global snapshot', 'partial-strong-global,snapshot')]
    [TestCase('partial-strong-global sessioncold', 'partial-strong-global,sessioncold')]
    [TestCase('partial-strong-global sessionwarm', 'partial-strong-global,sessionwarm')]
    [TestCase('partial-strong-global standalone', 'partial-strong-global,standalone')]
    [TestCase('partial-noconst-control cold', 'partial-noconst-control,cold')]
    [TestCase('partial-noconst-control snapshot', 'partial-noconst-control,snapshot')]
    [TestCase('partial-noconst-control sessioncold', 'partial-noconst-control,sessioncold')]
    [TestCase('partial-noconst-control sessionwarm', 'partial-noconst-control,sessionwarm')]
    [TestCase('partial-noconst-control standalone', 'partial-noconst-control,standalone')]
    [TestCase('partial-verified-control cold', 'partial-verified-control,cold')]
    [TestCase('partial-verified-control snapshot', 'partial-verified-control,snapshot')]
    [TestCase('partial-verified-control sessioncold', 'partial-verified-control,sessioncold')]
    [TestCase('partial-verified-control sessionwarm', 'partial-verified-control,sessionwarm')]
    [TestCase('partial-verified-control standalone', 'partial-verified-control,standalone')]
    [TestCase('partial-root-object cold', 'partial-root-object,cold')]
    [TestCase('partial-root-object snapshot', 'partial-root-object,snapshot')]
    [TestCase('partial-root-object sessioncold', 'partial-root-object,sessioncold')]
    [TestCase('partial-root-object sessionwarm', 'partial-root-object,sessionwarm')]
    [TestCase('partial-root-object standalone', 'partial-root-object,standalone')]
    [TestCase('partial-root-interfaced cold', 'partial-root-interfaced,cold')]
    [TestCase('partial-root-interfaced snapshot', 'partial-root-interfaced,snapshot')]
    [TestCase('partial-root-interfaced sessioncold', 'partial-root-interfaced,sessioncold')]
    [TestCase('partial-root-interfaced sessionwarm', 'partial-root-interfaced,sessionwarm')]
    [TestCase('partial-root-interfaced standalone', 'partial-root-interfaced,standalone')]
    [TestCase('partial-root-component cold', 'partial-root-component,cold')]
    [TestCase('partial-root-component snapshot', 'partial-root-component,snapshot')]
    [TestCase('partial-root-component sessioncold', 'partial-root-component,sessioncold')]
    [TestCase('partial-root-component sessionwarm', 'partial-root-component,sessionwarm')]
    [TestCase('partial-root-component standalone', 'partial-root-component,standalone')]
    [TestCase('partial-indexed-ancestor cold', 'partial-indexed-ancestor,cold')]
    [TestCase('partial-indexed-ancestor snapshot', 'partial-indexed-ancestor,snapshot')]
    [TestCase('partial-indexed-ancestor sessioncold', 'partial-indexed-ancestor,sessioncold')]
    [TestCase('partial-indexed-ancestor sessionwarm', 'partial-indexed-ancestor,sessionwarm')]
    [TestCase('partial-indexed-ancestor standalone', 'partial-indexed-ancestor,standalone')]
    [TestCase('anon-partial-field cold', 'anon-partial-field,cold')]
    [TestCase('anon-partial-field snapshot', 'anon-partial-field,snapshot')]
    [TestCase('anon-partial-field sessioncold', 'anon-partial-field,sessioncold')]
    [TestCase('anon-partial-field sessionwarm', 'anon-partial-field,sessionwarm')]
    [TestCase('anon-partial-field standalone', 'anon-partial-field,standalone')]
    [TestCase('anon-partial-include cold', 'anon-partial-include,cold')]
    [TestCase('anon-partial-include snapshot', 'anon-partial-include,snapshot')]
    [TestCase('anon-partial-include sessioncold', 'anon-partial-include,sessioncold')]
    [TestCase('anon-partial-include sessionwarm', 'anon-partial-include,sessionwarm')]
    [TestCase('anon-partial-include standalone', 'anon-partial-include,standalone')]
    [TestCase('anon-local-control cold', 'anon-local-control,cold')]
    [TestCase('anon-local-control snapshot', 'anon-local-control,snapshot')]
    [TestCase('anon-local-control sessioncold', 'anon-local-control,sessioncold')]
    [TestCase('anon-local-control sessionwarm', 'anon-local-control,sessionwarm')]
    [TestCase('anon-local-control standalone', 'anon-local-control,standalone')]
    [TestCase('anon-pointer-control cold', 'anon-pointer-control,cold')]
    [TestCase('anon-pointer-control snapshot', 'anon-pointer-control,snapshot')]
    [TestCase('anon-pointer-control sessioncold', 'anon-pointer-control,sessioncold')]
    [TestCase('anon-pointer-control sessionwarm', 'anon-pointer-control,sessionwarm')]
    [TestCase('anon-pointer-control standalone', 'anon-pointer-control,standalone')]
    [TestCase('anon-partial-enum cold', 'anon-partial-enum,cold')]
    [TestCase('anon-partial-enum snapshot', 'anon-partial-enum,snapshot')]
    [TestCase('anon-partial-enum sessioncold', 'anon-partial-enum,sessioncold')]
    [TestCase('anon-partial-enum sessionwarm', 'anon-partial-enum,sessionwarm')]
    [TestCase('anon-partial-enum standalone', 'anon-partial-enum,standalone')]
    procedure ValueMemberQualificationRequiresVerifiedReceiver(const aShape, aMode: string);
    [Category('DS731NestedPartialReceiver')]
    [TestCase('nested-parent-trigger cold', 'nested-parent-trigger,cold')]
    [TestCase('nested-parent-trigger snapshot', 'nested-parent-trigger,snapshot')]
    [TestCase('nested-parent-trigger sessioncold', 'nested-parent-trigger,sessioncold')]
    [TestCase('nested-parent-trigger sessionwarm', 'nested-parent-trigger,sessionwarm')]
    [TestCase('nested-parent-trigger standalone', 'nested-parent-trigger,standalone')]
    [TestCase('nested-parent-noglobal cold', 'nested-parent-noglobal,cold')]
    [TestCase('nested-parent-noglobal snapshot', 'nested-parent-noglobal,snapshot')]
    [TestCase('nested-parent-noglobal sessioncold', 'nested-parent-noglobal,sessioncold')]
    [TestCase('nested-parent-noglobal sessionwarm', 'nested-parent-noglobal,sessionwarm')]
    [TestCase('nested-parent-noglobal standalone', 'nested-parent-noglobal,standalone')]
    [TestCase('nested-child-trigger cold', 'nested-child-trigger,cold')]
    [TestCase('nested-child-trigger snapshot', 'nested-child-trigger,snapshot')]
    [TestCase('nested-child-trigger sessioncold', 'nested-child-trigger,sessioncold')]
    [TestCase('nested-child-trigger sessionwarm', 'nested-child-trigger,sessionwarm')]
    [TestCase('nested-child-trigger standalone', 'nested-child-trigger,standalone')]
    [TestCase('nested-three-level cold', 'nested-three-level,cold')]
    [TestCase('nested-three-level snapshot', 'nested-three-level,snapshot')]
    [TestCase('nested-three-level sessioncold', 'nested-three-level,sessioncold')]
    [TestCase('nested-three-level sessionwarm', 'nested-three-level,sessionwarm')]
    [TestCase('nested-three-level standalone', 'nested-three-level,standalone')]
    [TestCase('nested-siblings cold', 'nested-siblings,cold')]
    [TestCase('nested-siblings snapshot', 'nested-siblings,snapshot')]
    [TestCase('nested-siblings sessioncold', 'nested-siblings,sessioncold')]
    [TestCase('nested-siblings sessionwarm', 'nested-siblings,sessionwarm')]
    [TestCase('nested-siblings standalone', 'nested-siblings,standalone')]
    [TestCase('nested-verified-control cold', 'nested-verified-control,cold')]
    [TestCase('nested-verified-control snapshot', 'nested-verified-control,snapshot')]
    [TestCase('nested-verified-control sessioncold', 'nested-verified-control,sessioncold')]
    [TestCase('nested-verified-control sessionwarm', 'nested-verified-control,sessionwarm')]
    [TestCase('nested-verified-control standalone', 'nested-verified-control,standalone')]
    [TestCase('nested-unrelated-control cold', 'nested-unrelated-control,cold')]
    [TestCase('nested-unrelated-control snapshot', 'nested-unrelated-control,snapshot')]
    [TestCase('nested-unrelated-control sessioncold', 'nested-unrelated-control,sessioncold')]
    [TestCase('nested-unrelated-control sessionwarm', 'nested-unrelated-control,sessionwarm')]
    [TestCase('nested-unrelated-control standalone', 'nested-unrelated-control,standalone')]
    procedure NestedValueQualificationRequiresVerifiedReceiver(const aShape, aMode: string);
    [Category('DS731Standalone')]
    [TestCase('tag-only', 'tag-only')]
    [TestCase('record-constant', 'record-constant')]
    [TestCase('anonymous-inactive', 'anonymous-inactive')]
    [TestCase('anonymous-include', 'anonymous-include')]
    [TestCase('indexed-named-tag', 'indexed-named-tag')]
    [TestCase('strong-alias-qualified-target', 'strong-alias-qualified-target')]
    [TestCase('helper-unrelated', 'helper-unrelated')]
    [TestCase('num-rec', 'num-rec')]
    procedure ValueMembersStandaloneSqlite(const aShape: string);
    [Category('DS731EvidenceIntegrity')]
    [TestCase('old-cache', 'missing')]
    [TestCase('partial-owner-rows', 'fields')]
    [TestCase('missing-unit', 'models')]
    [TestCase('partial-name-rows', 'values')]
    [TestCase('count-mismatch', 'checksum')]
    [TestCase('format', 'format')]
    procedure StandaloneValueEvidenceRejectsPartial(const aShape: string);


    [TestCase('rc-global-read', 'rc-global-read')]
    [TestCase('rc-noglobal-read', 'rc-noglobal-read')]
    [TestCase('rc-header-sameline', 'rc-header-sameline')]
    [TestCase('rc-sameline-end', 'rc-sameline-end')]
    [TestCase('rc-typed', 'rc-typed')]
    [TestCase('vt-global-read', 'vt-global-read')]
    [TestCase('vt-noglobal-read', 'vt-noglobal-read')]
    [TestCase('vt-header-sameline', 'vt-header-sameline')]
    [TestCase('vt-alias-recv', 'vt-alias-recv')]
    [TestCase('vt-nested-with', 'vt-nested-with')]
    [TestCase('cc-inherited', 'cc-inherited')]
    [Category('DS731')]
    procedure TypeValueMembersBind(const aShape: string);
    [TestCase('rc-global-read', 'rc-global-read')]
    [TestCase('rc-noglobal-read', 'rc-noglobal-read')]
    [TestCase('rc-header-sameline', 'rc-header-sameline')]
    [TestCase('rc-sameline-end', 'rc-sameline-end')]
    [TestCase('rc-typed', 'rc-typed')]
    [TestCase('vt-global-read', 'vt-global-read')]
    [TestCase('vt-noglobal-read', 'vt-noglobal-read')]
    [TestCase('vt-header-sameline', 'vt-header-sameline')]
    [TestCase('vt-alias-recv', 'vt-alias-recv')]
    [TestCase('vt-nested-with', 'vt-nested-with')]
    [TestCase('cc-inherited', 'cc-inherited')]
    [TestCase('rc-global-read LF', 'rc-global-read-lf')]
    [TestCase('vt-global-read LF', 'vt-global-read-lf')]
    [Category('DS731')]
    procedure TypeValueMembersPlan(const aShape: string);
    function TypeValueMemberModels(const aShape: string): TArray<TDelphiSemanticUnitModel>;
    [TestCase('Lost helper facts', 'lost')]
    [TestCase('Overload visibility sites', 'overloads')]
    [TestCase('Two routine visibility sites', 'routines')]
    procedure UnindexedHelperCacheAndLostFacts(const aMode: string);
    [Test]
    procedure UnindexedHelperColdWarmSnapshot;
    [TestCase('Null imported helper target', 'null-target')]
    [TestCase('Null imported helper fact', 'null')]
    [TestCase('Imported helper fact without target', 'missing-target')]
    [TestCase('Name JSON number', 'Name:number')]
    [TestCase('Name JSON bool', 'Name:bool')]
    [TestCase('Name JSON null', 'Name:null')]
    [TestCase('HelperKind JSON number', 'HelperKind:number')]
    [TestCase('HelperKind JSON bool', 'HelperKind:bool')]
    [TestCase('HelperKind JSON null', 'HelperKind:null')]
    [TestCase('TargetName JSON number', 'TargetName:number')]
    [TestCase('TargetName JSON bool', 'TargetName:bool')]
    [TestCase('TargetName JSON null', 'TargetName:null')]
    [TestCase('SectionKind JSON number', 'SectionKind:number')]
    [TestCase('SectionKind JSON bool', 'SectionKind:bool')]
    [TestCase('SectionKind JSON null', 'SectionKind:null')]
    [TestCase('ScopeKind JSON number', 'ScopeKind:number')]
    [TestCase('ScopeKind JSON bool', 'ScopeKind:bool')]
    [TestCase('ScopeKind JSON null', 'ScopeKind:null')]
    [TestCase('OwnerScopeId JSON number', 'OwnerScopeId:number')]
    [TestCase('OwnerScopeId JSON bool', 'OwnerScopeId:bool')]
    [TestCase('OwnerScopeId JSON null', 'OwnerScopeId:null')]
    [TestCase('FileName JSON number', 'FileName:number')]
    [TestCase('FileName JSON bool', 'FileName:bool')]
    [TestCase('FileName JSON null', 'FileName:null')]
    [TestCase('HelperKind unknown value', 'HelperKind:bogus')]
    [TestCase('SectionKind unknown value', 'SectionKind:bogus')]
    [TestCase('ScopeKind unknown value', 'ScopeKind:bogus')]
    procedure MalformedImportedHelperFactsFailClosed(const aMode: string);
    [TestCase('Empty writer helper kind', 'kind')]
    [TestCase('Empty writer helper target', 'target')]
    procedure UnindexedHelperWriterValuesRoundTrip(const aMode: string);
    [TestCase('Line coordinate string', 'Line:string')]
    [TestCase('Line coordinate float', 'Line:float')]
    [TestCase('Line coordinate null', 'Line:null')]
    [TestCase('Line coordinate missing', 'Line:missing')]
    [TestCase('Line coordinate bool', 'Line:bool')]
    [TestCase('Line coordinate array', 'Line:array')]
    [TestCase('Line coordinate object', 'Line:object')]
    [TestCase('Line coordinate negative', 'Line:negative')]
    [TestCase('Line coordinate overflow', 'Line:overflow')]
    [TestCase('Column coordinate string', 'Column:string')]
    [TestCase('Column coordinate float', 'Column:float')]
    [TestCase('Column coordinate null', 'Column:null')]
    [TestCase('Column coordinate missing', 'Column:missing')]
    [TestCase('Column coordinate bool', 'Column:bool')]
    [TestCase('Column coordinate array', 'Column:array')]
    [TestCase('Column coordinate object', 'Column:object')]
    [TestCase('Column coordinate negative', 'Column:negative')]
    [TestCase('Column coordinate overflow', 'Column:overflow')]
    procedure MalformedHelperCoordinatesFailClosed(const aMode: string);
    [TestCase('Writer coordinates position', 'position')]
    [TestCase('Writer coordinates zero', 'zero')]
    procedure HelperCoordinatesWriterRoundTrip(const aMode: string);
    [TestCase('Duplicate unit site models', 'forward')]
    [TestCase('Reversed duplicate unit site models', 'reverse')]
    procedure UnindexedHelperCacheSeparatesSiteModels(const aOrder: string);
    [TestCase('Root helper after include and site', 'after')]
    [TestCase('Root helper before site after include', 'before')]
    [TestCase('Helper inside include', 'included')]
    procedure UnindexedHelperIncludeOrigins(const aMode: string);
    [TestCase('unrelated', 'unrelated')]
    [TestCase('same-name', 'same-name')]
    [TestCase('private-import', 'private-import')]
    [TestCase('after-site', 'after-site')]
    [TestCase('class-helper', 'class-helper')]
    [TestCase('indexed-import', 'indexed-import')]
    [TestCase('import', 'import')]
    [TestCase('call', 'call')]
    [TestCase('alias-target', 'alias-target')]
    [TestCase('alias-receiver', 'alias-receiver')]
    [TestCase('local-alias', 'local-alias')]
    [TestCase('nested', 'nested')]
    [TestCase('intrinsic', 'intrinsic')]
    [TestCase('local-array', 'local-array')]
    [TestCase('no-helper', 'no-helper')]
    procedure UnindexedRecordHelperRequiresVisibleMatchingIdentity(const aShape: string);
    [TestCase('Imported routine homonym', 'cross')]
    [TestCase('Same unit routine homonym', 'direct')]
    procedure RoutineTypeHomonymCannotSupplyReceiverMember(const aShape: string);
    [TestCase('Operator local is an identifier', 'local')]
    [TestCase('Operator field is an identifier', 'field')]
    procedure OperatorIdentifierDoesNotHideDeclarations(const aShape: string);
    [TestCase('Exact reviewer plain alias', 'alias-plain')]
    [TestCase('Exact reviewer pointer alias', 'alias-ptr')]
    [TestCase('Inherited indexed homonym', 'inherited-index')]
    [TestCase('Inherited pointer homonym', 'inherited-pointer')]
    [TestCase('Alias indexed homonym', 'alias-index')]
    [TestCase('Alias pointer homonym', 'alias-pointer')]
    procedure VerifiedCrossUnitReceiverKeepsMember(const aShape: string);
    [TestCase('Selected unknown member', 'selected-unknown')]
    [TestCase('Selected unknown selector path', 'selector-selected')]
    [TestCase('Context index foreign owner', 'context-borrow')]
    [TestCase('Lexical homonym retains lexical binding', 'homonym-lexical')]
    [TestCase('Unit constant cannot borrow a foreign receiver member', 'homonym-constant')]
    [TestCase('Routine-local unknown member', 'local-type')]
    [TestCase('Unknown lexical without homonym stays planned', 'lexical-unknown-no-homonym')]
    [TestCase('Known-inactive miss keeps ordinary candidate', 'known-inactive-member')]
    procedure ReceiverOwnerIdentityAndMemberActivity(const aShape: string);
    [Test]
    procedure FieldSelectorsRetainTheirDeclaredKinds;
    [Test]
    [TestCase('Complete source import', 'complete,resolved')]
    [TestCase('Unknown source import', 'missing,unsupported')]
    [TestCase('Ambiguous source import', 'ambiguous,unsupported')]
    [TestCase('Imported helper', 'helper,unsupported')]
    [TestCase('Escaped helper name', 'helper-escaped-name,unsupported')]
    [TestCase('Omitted empty helper declaration', 'helper-unindexed-empty,unsupported')]
    [TestCase('Verified record helper', 'record-helper,resolved')]
    [TestCase('Routine-local record target homonym', 'record-helper-local,unsupported')]
    [TestCase('Record alias target stays conservative', 'record-helper-alias,unsupported')]
    [TestCase('Unresolved record helper target', 'record-helper-missing,unsupported')]
    [TestCase('Unverified helper kind', 'helper-unverified,unsupported')]
    [TestCase('Class helper with missing heuristic target', 'helper-empty-target,unsupported')]
    [TestCase('Failed imported source', 'failed,unsupported')]
    [TestCase('Interface-only import', 'interface-only,unsupported')]
    [TestCase('Mismatched rejection count', 'rejected,unsupported')]
    [TestCase('Verified unit routine omissions', 'routine-complete,resolved')]
    [TestCase('Unverified routine signature', 'routine-unverified,unsupported')]
    [TestCase('Wrong routine source position', 'routine-position,unsupported')]
    [TestCase('Nested routine ownership', 'routine-parent,unsupported')]
    [TestCase('Wrong declaration source', 'routine-declaration-file,unsupported')]
    [TestCase('Wrong declaration scope', 'routine-declaration-scope,unsupported')]
    [TestCase('Wrong declaration owner', 'routine-declaration-owner,unsupported')]
    [TestCase('Wrong declaration owner scope', 'routine-declaration-owner-scope,unsupported')]
    procedure RootAbsenceRequiresClosedImportedSource(const aBarrier, aExpectedStatus: string);

    [Test]
    [TestCase('Missing root evidence', 'missing,lPair,unsupported')]
    [TestCase('Exact absence evidence', 'accepted,lPair,resolved')]
    [TestCase('Root member refusal', 'refused,ClassName,unsupported')]
    procedure SimpleSelectorFallthroughRequiresExactRootAbsence(
      const aMode, aName, aExpectedStatus: string);

    [Test]
    [TestCase('MissingProvider', 'missing')]
    [TestCase('ImportedUnit', 'import')]
    [TestCase('ReachableHelper', 'helper')]
    [TestCase('UnknownAncestor', 'ancestor')]
    [TestCase('FailedModel', 'failed')]
    [TestCase('InterfaceOnly', 'interface-only')]
    [TestCase('RejectedDeclaration', 'rejected')]
    [TestCase('SystemOrigin', 'system')]
    procedure OptionalRootAbsenceKeepsUnverifiedContextsBlocked(const aBarrier: string);
    [Test]
    procedure OptionalRootAbsenceFlowsThroughApiAndBypassesPersistentFacts;
    [TestCase('Public remove-with plan', 'plan')]
    [TestCase('Public project load', 'project')]
    [TestCase('Public project session', 'session')]
    procedure PublicProviderFingerprintFailureRefuses(const aPath: string);
    [TestCase('Conditional ancestor declaration homonym', 'ancestor-declaration')]
    [TestCase('Declared receiver borrows foreign member', 'declared-receiver')]
    [TestCase('Unknown declaration in active WITH', 'declaration')]
    [TestCase('Unknown selected field', 'selected-field')]
    [TestCase('Unknown global', 'global')]
    [TestCase('Unknown local', 'local')]
    [TestCase('Unknown selector member', 'selector')]
    [TestCase('Unknown nested statement blocks parent', 'nested')]
    [TestCase('Known-active declaration control', 'active')]
    [TestCase('Known-false declaration is absent', 'inactive')]
    [TestCase('Unknown inner activity skips parent', 'activity-nested')]
    [TestCase('Mixed unknown WITH', 'mixed')]
    [TestCase('Missing unknown include WITH', 'missing')]
    [TestCase('Unmodeled directive WITH', 'directive')]
    procedure UnknownActivityCannotAuthorizeRemoveWith(const aShape: string);
    [TestCase('Hidden IF ELSE nested WITH', 'hidden-if')]
    [TestCase('Hidden Declared nested WITH', 'hidden-declared')]
    [TestCase('Malformed IFDEF nested WITH', 'hidden-malformed')]
    [TestCase('Uncaptured LINUX nested WITH', 'hidden-linux')]
    [TestCase('Missing include inside WITH', 'hidden-missing')]
    [TestCase('Include only inside unknown WITH', 'hidden-include')]
    [TestCase('Unknown selector text', 'selector-text')]
    [TestCase('Global taint invalidates earlier UNDEF', 'taint')]
    [TestCase('Conditional ancestor control receiver', 'ancestor-control')]
    [TestCase('Unresolved reason wins activity', 'binder-unresolved')]
    [TestCase('Plannable scoped body is activity-unverified', 'binder-scoped')]
    procedure WholeWithSourceActivityIsRequired(const aShape: string);

    [TestCase('same cold', 'same,cold')]
    [TestCase('same warm', 'same,warm')]
    [TestCase('same snapshot', 'same,snapshot')]
    [TestCase('different cold', 'different,cold')]
    [TestCase('different warm', 'different,warm')]
    [TestCase('different snapshot', 'different,snapshot')]
    [TestCase('absent cold', 'absent,cold')]
    [TestCase('absent warm', 'absent,warm')]
    [TestCase('absent snapshot', 'absent,snapshot')]
    [TestCase('unresolved cold', 'unresolved,cold')]
    [TestCase('unresolved warm', 'unresolved,warm')]
    [TestCase('unresolved snapshot', 'unresolved,snapshot')]
    [TestCase('block cold', 'block,cold')]
    [TestCase('block warm', 'block,warm')]
    [TestCase('block snapshot', 'block,snapshot')]
    [TestCase('unknown cold', 'unknown,cold')]
    [TestCase('unknown warm', 'unknown,warm')]
    [TestCase('unknown snapshot', 'unknown,snapshot')]
    [TestCase('active cold', 'active,cold')]
    [TestCase('active warm', 'active,warm')]
    [TestCase('active snapshot', 'active,snapshot')]
    [TestCase('plain cold', 'plain,cold')]
    [TestCase('plain warm', 'plain,warm')]
    [TestCase('plain snapshot', 'plain,snapshot')]
    [TestCase('multi cold', 'multi,cold')]
    [TestCase('multi warm', 'multi,warm')]
    [TestCase('multi snapshot', 'multi,snapshot')]
    [TestCase('comment cold', 'comment,cold')]
    [TestCase('comment warm', 'comment,warm')]
    [TestCase('comment snapshot', 'comment,snapshot')]
    [TestCase('string cold', 'string,cold')]
    [TestCase('string warm', 'string,warm')]
    [TestCase('string snapshot', 'string,snapshot')]
    [TestCase('indexed cold', 'indexed,cold')]
    [TestCase('indexed warm', 'indexed,warm')]
    [TestCase('indexed snapshot', 'indexed,snapshot')]
    [TestCase('deref cold', 'deref,cold')]
    [TestCase('deref warm', 'deref,warm')]
    [TestCase('deref snapshot', 'deref,snapshot')]
    [TestCase('call cold', 'call,cold')]
    [TestCase('call warm', 'call,warm')]
    [TestCase('call snapshot', 'call,snapshot')]
    [TestCase('split cold', 'split,cold')]
    [TestCase('split warm', 'split,warm')]
    [TestCase('split snapshot', 'split,snapshot')]
    [TestCase('nested-span cold', 'nested-span,cold')]
    [TestCase('nested-span warm', 'nested-span,warm')]
    [TestCase('nested-span snapshot', 'nested-span,snapshot')]
    [TestCase('nested-with cold', 'nested-with,cold')]
    [TestCase('nested-with warm', 'nested-with,warm')]
    [TestCase('nested-with snapshot', 'nested-with,snapshot')]
    [TestCase('fix1 header-active cold', 'header-active,cold')]
    [TestCase('fix1 header-active warm', 'header-active,warm')]
    [TestCase('fix1 header-active snapshot', 'header-active,snapshot')]
    [TestCase('fix1 header-active-ml cold', 'header-active-ml,cold')]
    [TestCase('fix1 header-active-ml warm', 'header-active-ml,warm')]
    [TestCase('fix1 header-active-ml snapshot', 'header-active-ml,snapshot')]
    [TestCase('fix1 header-active-lf cold', 'header-active-lf,cold')]
    [TestCase('fix1 header-active-lf warm', 'header-active-lf,warm')]
    [TestCase('fix1 header-active-lf snapshot', 'header-active-lf,snapshot')]
    [TestCase('fix1 inline-shadow cold', 'inline-shadow,cold')]
    [TestCase('fix1 inline-shadow warm', 'inline-shadow,warm')]
    [TestCase('fix1 inline-shadow snapshot', 'inline-shadow,snapshot')]
    [TestCase('fix1 anonymous-shadow cold', 'anonymous-shadow,cold')]
    [TestCase('fix1 anonymous-shadow warm', 'anonymous-shadow,warm')]
    [TestCase('fix1 anonymous-shadow snapshot', 'anonymous-shadow,snapshot')]
    [TestCase('fix1 safe-before cold', 'safe-before,cold')]
    [TestCase('fix1 safe-before warm', 'safe-before,warm')]
    [TestCase('fix1 safe-before snapshot', 'safe-before,snapshot')]
    [TestCase('fix1 safe-after cold', 'safe-after,cold')]
    [TestCase('fix1 safe-after warm', 'safe-after,warm')]
    [TestCase('fix1 safe-after snapshot', 'safe-after,snapshot')]
    [TestCase('fix1 safe-two-spans cold', 'safe-two-spans,cold')]
    [TestCase('fix1 safe-two-spans warm', 'safe-two-spans,warm')]
    [TestCase('fix1 safe-two-spans snapshot', 'safe-two-spans,snapshot')]
    [TestCase('fix1 fake-brace cold', 'fake-brace,cold')]
    [TestCase('fix1 fake-brace warm', 'fake-brace,warm')]
    [TestCase('fix1 fake-brace snapshot', 'fake-brace,snapshot')]
    [TestCase('fix1 fake-star cold', 'fake-star,cold')]
    [TestCase('fix1 fake-star warm', 'fake-star,warm')]
    [TestCase('fix1 fake-star snapshot', 'fake-star,snapshot')]
    [TestCase('fix1 fake-line cold', 'fake-line,cold')]
    [TestCase('fix1 fake-line warm', 'fake-line,warm')]
    [TestCase('fix1 fake-line snapshot', 'fake-line,snapshot')]
    [TestCase('fix1 fake-string cold', 'fake-string,cold')]
    [TestCase('fix1 fake-string warm', 'fake-string,warm')]
    [TestCase('fix1 fake-string snapshot', 'fake-string,snapshot')]
    [TestCase('fix1 unicode-ident cold', 'unicode-ident,cold')]
    [TestCase('fix1 unicode-ident warm', 'unicode-ident,warm')]
    [TestCase('fix1 unicode-ident snapshot', 'unicode-ident,snapshot')]
    [TestCase('fix1 suffix-ident cold', 'suffix-ident,cold')]
    [TestCase('fix1 suffix-ident warm', 'suffix-ident,warm')]
    [TestCase('fix1 suffix-ident snapshot', 'suffix-ident,snapshot')]
    [TestCase('fix1 escaped-ident cold', 'escaped-ident,cold')]
    [TestCase('fix1 escaped-ident warm', 'escaped-ident,warm')]
    [TestCase('fix1 escaped-ident snapshot', 'escaped-ident,snapshot')]
    [TestCase('fix2 v3-simple cold', 'v3-simple,cold')]
    [TestCase('fix2 v3-simple warm', 'v3-simple,warm')]
    [TestCase('fix2 v3-simple snapshot', 'v3-simple,snapshot')]
    [TestCase('fix2 v3-if cold', 'v3-if,cold')]
    [TestCase('fix2 v3-if warm', 'v3-if,warm')]
    [TestCase('fix2 v3-if snapshot', 'v3-if,snapshot')]
    [TestCase('fix2 v3-routine-var cold', 'v3-routine-var,cold')]
    [TestCase('fix2 v3-routine-var warm', 'v3-routine-var,warm')]
    [TestCase('fix2 v3-routine-var snapshot', 'v3-routine-var,snapshot')]
    [TestCase('fix2 v3-global-else cold', 'v3-global-else,cold')]
    [TestCase('fix2 v3-global-else warm', 'v3-global-else,warm')]
    [TestCase('fix2 v3-global-else snapshot', 'v3-global-else,snapshot')]
    [TestCase('fix2 v3-record-field cold', 'v3-record-field,cold')]
    [TestCase('fix2 v3-record-field warm', 'v3-record-field,warm')]
    [TestCase('fix2 v3-record-field snapshot', 'v3-record-field,snapshot')]
    [TestCase('fix2 v3-inline-before cold', 'v3-inline-before,cold')]
    [TestCase('fix2 v3-inline-before warm', 'v3-inline-before,warm')]
    [TestCase('fix2 v3-inline-before snapshot', 'v3-inline-before,snapshot')]
    [TestCase('fix2 v3-routine-before cold', 'v3-routine-before,cold')]
    [TestCase('fix2 v3-routine-before warm', 'v3-routine-before,warm')]
    [TestCase('fix2 v3-routine-before snapshot', 'v3-routine-before,snapshot')]
    [TestCase('fix3 v4-sibling cold', 'v4-sibling,cold')]
    [TestCase('fix3 v4-sibling warm', 'v4-sibling,warm')]
    [TestCase('fix3 v4-sibling snapshot', 'v4-sibling,snapshot')]
    [TestCase('fix3 v4-active-sub cold', 'v4-active-sub,cold')]
    [TestCase('fix3 v4-active-sub warm', 'v4-active-sub,warm')]
    [TestCase('fix3 v4-active-sub snapshot', 'v4-active-sub,snapshot')]
    [TestCase('fix3 v4-sol-sibling cold', 'v4-sol-sibling,cold')]
    [TestCase('fix3 v4-sol-sibling warm', 'v4-sol-sibling,warm')]
    [TestCase('fix3 v4-sol-sibling snapshot', 'v4-sol-sibling,snapshot')]
    [TestCase('fix3 v4-comma cold', 'v4-comma,cold')]
    [TestCase('fix3 v4-comma warm', 'v4-comma,warm')]
    [TestCase('fix3 v4-comma snapshot', 'v4-comma,snapshot')]
    [TestCase('fix3 v4-comma-noref cold', 'v4-comma-noref,cold')]
    [TestCase('fix3 v4-comma-noref warm', 'v4-comma-noref,warm')]
    [TestCase('fix3 v4-comma-noref snapshot', 'v4-comma-noref,snapshot')]
    [TestCase('fix3 v4-comma-absent cold', 'v4-comma-absent,cold')]
    [TestCase('fix3 v4-comma-absent warm', 'v4-comma-absent,warm')]
    [TestCase('fix3 v4-comma-absent snapshot', 'v4-comma-absent,snapshot')]
    [TestCase('fix3 v4-no-outer-ref cold', 'v4-no-outer-ref,cold')]
    [TestCase('fix3 v4-no-outer-ref warm', 'v4-no-outer-ref,warm')]
    [TestCase('fix3 v4-no-outer-ref snapshot', 'v4-no-outer-ref,snapshot')]
    [TestCase('fix3 v4-fake-brace cold', 'v4-fake-brace,cold')]
    [TestCase('fix3 v4-fake-brace warm', 'v4-fake-brace,warm')]
    [TestCase('fix3 v4-fake-brace snapshot', 'v4-fake-brace,snapshot')]
    [TestCase('fix3 v4-fake-star cold', 'v4-fake-star,cold')]
    [TestCase('fix3 v4-fake-star warm', 'v4-fake-star,warm')]
    [TestCase('fix3 v4-fake-star snapshot', 'v4-fake-star,snapshot')]
    [TestCase('fix3 v4-fake-line cold', 'v4-fake-line,cold')]
    [TestCase('fix3 v4-fake-line warm', 'v4-fake-line,warm')]
    [TestCase('fix3 v4-fake-line snapshot', 'v4-fake-line,snapshot')]
    [TestCase('fix3 v4-fake-string cold', 'v4-fake-string,cold')]
    [TestCase('fix3 v4-fake-string warm', 'v4-fake-string,warm')]
    [TestCase('fix3 v4-fake-string snapshot', 'v4-fake-string,snapshot')]
    [TestCase('fix3 v4-outside cold', 'v4-outside,cold')]
    [TestCase('fix3 v4-outside warm', 'v4-outside,warm')]
    [TestCase('fix3 v4-outside snapshot', 'v4-outside,snapshot')]
    [TestCase('fix3 v4-prefix-ident cold', 'v4-prefix-ident,cold')]
    [TestCase('fix3 v4-prefix-ident warm', 'v4-prefix-ident,warm')]
    [TestCase('fix3 v4-prefix-ident snapshot', 'v4-prefix-ident,snapshot')]
    [TestCase('fix4 v4-include-short cold', 'v4-include-short,cold')]
    [TestCase('fix4 v4-include-short warm', 'v4-include-short,warm')]
    [TestCase('fix4 v4-include-short snapshot', 'v4-include-short,snapshot')]
    [TestCase('fix4 v4-include-long cold', 'v4-include-long,cold')]
    [TestCase('fix4 v4-include-long warm', 'v4-include-long,warm')]
    [TestCase('fix4 v4-include-long snapshot', 'v4-include-long,snapshot')]
    [TestCase('fix4 v4-include-active cold', 'v4-include-active,cold')]
    [TestCase('fix4 v4-include-active warm', 'v4-include-active,warm')]
    [TestCase('fix4 v4-include-active snapshot', 'v4-include-active,snapshot')]
    [TestCase('polish d-deep-sibling cold', 'v4-polish-d-deep-sibling,cold')]
    [TestCase('polish d-deep-sibling warm', 'v4-polish-d-deep-sibling,warm')]
    [TestCase('polish d-deep-sibling snapshot', 'v4-polish-d-deep-sibling,snapshot')]
    [TestCase('polish i-lower cold', 'v4-polish-i-lower,cold')]
    [TestCase('polish i-lower warm', 'v4-polish-i-lower,warm')]
    [TestCase('polish i-lower snapshot', 'v4-polish-i-lower,snapshot')]
    [TestCase('polish i-paren cold', 'v4-polish-i-paren,cold')]
    [TestCase('polish i-paren warm', 'v4-polish-i-paren,warm')]
    [TestCase('polish i-paren snapshot', 'v4-polish-i-paren,snapshot')]
    [TestCase('polish i-quoted-space cold', 'v4-polish-i-quoted-space,cold')]
    [TestCase('polish i-quoted-space warm', 'v4-polish-i-quoted-space,warm')]
    [TestCase('polish i-quoted-space snapshot', 'v4-polish-i-quoted-space,snapshot')]
    [TestCase('polish i-include-quoted-space cold', 'v4-polish-i-include-quoted-space,cold')]
    [TestCase('polish i-include-quoted-space warm', 'v4-polish-i-include-quoted-space,warm')]
    [TestCase('polish i-include-quoted-space snapshot', 'v4-polish-i-include-quoted-space,snapshot')]
    [TestCase('polish x-switch-plus cold', 'v4-polish-x-switch-plus,cold')]
    [TestCase('polish x-switch-plus warm', 'v4-polish-x-switch-plus,warm')]
    [TestCase('polish x-switch-plus snapshot', 'v4-polish-x-switch-plus,snapshot')]
    [TestCase('polish x-switch-minus cold', 'v4-polish-x-switch-minus,cold')]
    [TestCase('polish x-switch-minus warm', 'v4-polish-x-switch-minus,warm')]
    [TestCase('polish x-switch-minus snapshot', 'v4-polish-x-switch-minus,snapshot')]
    [TestCase('polish x-inline cold', 'v4-polish-x-inline,cold')]
    [TestCase('polish x-inline warm', 'v4-polish-x-inline,warm')]
    [TestCase('polish x-inline snapshot', 'v4-polish-x-inline,snapshot')]
    procedure InactiveNestedWithShadowing(const aShape, aMode: string);
    [TestCase('Known-inactive homonym preserves base replacement', 'known')]
    [TestCase('Unknown homonym refuses whole statement', 'unknown')]
    procedure WholeWithRangeRefusesOnlyUnknownActivity(const aShape: string);

    [TestCase('Overload', 'overload')]
    [TestCase('Indexed inherited field', 'indexed')]
    [TestCase('Dereferenced inherited field', 'pointer')]
    procedure RootAbsenceNeverOverridesIndexedLineage(const aShape: string);
    [TestCase('Indexed local class', 'indexed')]
    [TestCase('Dereferenced local class', 'pointer')]
    procedure LocalLineageNeverBorrowsUnitTypeIdentity(const aShape: string);
    [TestCase('Fingerprint failure', 'fingerprint')]
    [TestCase('Absence failure', 'absence')]
    procedure RootAbsenceProviderFailureKeepsBindingUnsupported(const aMode: string);
    [TestCase('Record', 'record')]
    [TestCase('Indexed record', 'indexed')]
    [TestCase('Dereferenced record', 'pointer')]
    [TestCase('Unindexed imported helper coverage', 'import')]
    procedure UnindexedRecordHelperShieldsLexicalHomonym(const aShape: string);
    [TestCase('Ord', 'Ord')]
    [TestCase('SizeOf', 'SizeOf')]
    procedure CompilerRoutineInWithBodyUsesIntrinsicFallback(const aName: string);
    [TestCase('Member', 'member')]
    [TestCase('Lexical', 'lexical')]
    [TestCase('Unknown', 'unknown')]
    procedure IntrinsicFallbackPreservesNamePrecedenceAndUnknownRefusal(const aShape: string);
    [TestCase('Pointer', 'pointer')]
    [TestCase('Homonym', 'homonym')]
    [TestCase('Range', 'range')]
    [TestCase('UnknownBase', 'unknown')]
    procedure QualifiedPointerFieldNeverBindsToWithHomonym(const aShape: string);
    [TestCase('Inactive', 'false')]
    [TestCase('Active', 'true')]
    procedure ConditionalWithBodyOnlyBindsActiveReferences(const aActive: Boolean);
    [Test]
    procedure ResolvesSelectorTypesAndClassifiesBodyIdentifiers;
    [Test]
    procedure BindingsExposeSourceRangesForDakPlanner;
    [Test]
    procedure MultipleSelectorsPreferInnermostReceiver;
    [Test]
    procedure AmbiguousReceiverMembersClassifyAsAmbiguous;
    [Test]
    procedure ClassMethodWithBindingUsesOwnedRoutineTypeForInheritedProtectedMembers;
    [Test]
    procedure InheritedHomonymProjectionsKeepTheirAccessDeclaration;
    [Test]
    procedure OneLineTypeDeclarationsDoNotOpenMemberBodies;
    [Test]
    procedure IndexedPropertySelectorWithoutDereferenceStaysUnsupported;
    [Test]
    procedure MemberReferenceReportsRoutineScopeConflict;
    [Test]
    procedure UnresolvedSelectorMarksBodyReferencesExternal;
    [Test]
    procedure UnresolvedReceiverShieldsOuterAndLexicalHomonyms;
    [Test]
    procedure NestedWithStatementsUseOuterReceiverStack;
    [Test]
    procedure NestedRoutineWithUsesParentRoutineScope;
    [Test]
    procedure SiblingRoutineLocalsDoNotLeakIntoNestedWith;
    [Test]
    procedure PlanningMetadataCountsLookupSourcesAndReasons;
    [Test]
    procedure ScopedDeclarationsMarkBindingSkipped;
    [Test]
    procedure ControlCharacterLiteralsAreIgnored;
    [Test]
    procedure SafeBindingsArePlannedDirectReferences;
    [Test]
    procedure SkipReasonsCoverExternalAndUnresolvedBranches;
    [Test]
    procedure CastExpressionRolesRemainUnsupported;
    [Test]
    procedure InventoryExposesFileAwareSymbolsAndBindings;
    [Test]
    procedure InventoryExposesDakPlannerSourceModelFacts;
    [Test]
    procedure InventoryExpansionUsesIndexedOwnMemberLookup;
    [Test]
    procedure InventoryExpansionUsesStableRelatedMemberOwnerIndex;
    [Test]
    procedure InventoryExpansionIndexesCurrentClassProjectionContexts;
    [Test]
    procedure InventoryExpansionScopesCurrentClassProjectionByUnit;
    [Test]
    procedure ReferenceScannerPreservesRepresentativeTokenShapes;
    [Test]
    procedure ReferenceBindingUsesManualIdentifierScanner;
    [Test]
    procedure InventoryExpansionUsesOrdinalIgnoreCaseSymbolKeys;
    [Test]
    procedure InventoryExpansionDeduplicatesSymbolsCaseInsensitively;
    [Test]
    procedure AnonymousNestedRecordSelectorsUseSyntheticOwner;
    [Test]
    procedure GlobalAnonymousRecordSelectorUsesSyntheticOwner;
    [Test]
    procedure DefaultIndexedPropertyPointerSelectorDereferencesToRecord;
    [Test]
    procedure NestedParentDefaultIndexedPropertyPointerSelectorDereferencesToRecord;
    [Test]
    procedure NestedParentIndexedSelectorPreservesPrecedenceAndSafety;
    [Test]
    procedure NestedUnresolvedSelectorRefusesFinalRewrite;
    [Test]
    procedure NestedIndexedSelectorPreservesBoundTypeDeclaringUnit;
    [Test]
    procedure HiddenCompleteReceiverIgnoresUnrelatedDiagnostics;
    [Test]
    procedure AmbiguousFinalReceiverTypeFailsClosed;
    [Test]
    procedure HiddenReceiverExactOwnerDiagnosticsRefuse;
    [Test]
    procedure BareImportedReceiverUsesActualOwnerForSafety;
    [Test]
    procedure BareImportedReceiverWithoutVisibleOwnerIsRefused;
    [Test]
    procedure NestedLocalReceiverKeepsSourceScopeAndIdentity;
    [Test]
    procedure LocalPointerPointeeShadowsImportedUnitHomonym;
    [Test]
    procedure PointerAliasesResolvePointeesFromTheirDeclarationScopes;
    [Test]
    procedure RoutineLocalHomonymMembersUseTheirOwnDeclaration;
    [Test]
    procedure RoutineLocalInheritedMembersNeverBindElsewhere;
    [TestCase('UnitRecord', 'UnitRecord')]
    [TestCase('LocalRecord', 'LocalRecord')]
    [TestCase('UnitClass', 'UnitClass')]
    [TestCase('StrictPrivate', 'StrictPrivate')]
    [TestCase('UnfinalizableAlias', 'Unknown')]
    procedure FinalizedLocalAliasesUseTargetMemberIdentities(const aTargetKind: string);
    [TestCase('StrictPrivate', 'strict private')]
    [TestCase('Private', 'private')]
    [TestCase('StrictProtected', 'strict protected')]
    [TestCase('Protected', 'protected')]
    procedure LocalAliasVisibilityUsesCallerUnitIdentity(const aVisibility: string);
    [TestCase('UnindexedList', 'TStringList')]
    [TestCase('UnindexedRoot', 'TObject')]
    [TestCase('UnresolvedBase', 'TUnknownBase')]
    [TestCase('CompleteRecord', 'record')]
    procedure UnitReceiverWithUnindexedAncestorNeverBindsElsewhere(const aBaseTypeName: string);
    [Test]
    procedure MalformedPointerAliasOwnersAndAmbiguousPointeesAreRefused;
    [Test]
    procedure SelectorIdentityUsesTheDeclaringUnitScope;
    [Test]
    procedure ParameterTypesResolveInTheEnclosingScope;
  end;

implementation

uses
  System.Generics.Collections, System.Hash, System.IOUtils, System.JSON, System.JSON.Serializers, System.StrUtils, System.SysUtils,
  Winapi.Windows,
  FireDAC.Comp.Client, FireDAC.Phys.SQLite,
  AutoFree, maxLogic.IOUtils,
  DelphiSemantics.Api.ProjectOptions, DelphiSemantics.Cache, DelphiSemantics.Model.Json,
  DelphiSemantics.ProjectContext, DelphiSemantics.ProjectSession, DelphiSemantics.RemoveWithPlan,
  DelphiSemantics.Snapshot, DelphiSemantics.Snapshot.Builder,
  DelphiSemantics.Snapshot.Cache.Sqlite, DelphiSemantics.Snapshot.RemoveWith, Test.Support;

var
  GWithBinderTempRoot: string;

function WithBinderTempPath(const aName: string): string;
begin
  if GWithBinderTempRoot = '' then
  begin
    GWithBinderTempRoot := CreateTestTempRoot('with-binder-temp');
  end;
  TDirectory.CreateDirectory(GWithBinderTempRoot);
  Result := TPath.Combine(GWithBinderTempRoot, aName);
end;

type
  TImplicitRootAbsenceStub = class(TInterfacedObject, IDelphiSemanticImplicitRootMemberAbsence)
  public
    function EvidenceFingerprint: string;
    function IsNameAbsent(const aName: string): Boolean;
  end;

type
  // Provider failures are an external callback boundary exercised deliberately.
  TThrowingRootAbsenceProvider = class(TInterfacedObject, IDelphiSemanticImplicitRootMemberAbsence)
  private
    fMode: string;
  public
    constructor Create(const aMode: string);
    function EvidenceFingerprint: string;
    function IsNameAbsent(const aName: string): Boolean;
  end;

type
  TNamedRootAbsenceStub = class(TInterfacedObject, IDelphiSemanticImplicitRootMemberAbsence,
    IDelphiSemanticNamedRootMemberAbsence)
  public
    Mode: string;
    ImplicitCalls, NamedCalls: Integer;
    Root: TDelphiSemanticQualifiedRootType;
    SiteUnits: TArray<string>;
    Name: string;
    function EvidenceFingerprint: string;
    function IsNameAbsent(const aName: string): Boolean;
    function IsNamedRootMemberAbsent(const aRoot: TDelphiSemanticQualifiedRootType;
      const aSiteUnits: TArray<string>; const aName: string): Boolean;
  end;

  TRtlRootAbsenceStub = class(TInterfacedObject, IDelphiSemanticImplicitRootMemberAbsence,
    IDelphiSemanticNamedRootMemberAbsence)
  public
    function EvidenceFingerprint: string;
    function IsNameAbsent(const aName: string): Boolean;
    function IsNamedRootMemberAbsent(const aRoot: TDelphiSemanticQualifiedRootType;
      const aSiteUnits: TArray<string>; const aName: string): Boolean;
  end;

type
  TRtlImplicitAbsenceStub = class(TInterfacedObject, IDelphiSemanticImplicitRootMemberAbsence)
  public
    function EvidenceFingerprint: string;
    function IsNameAbsent(const aName: string): Boolean;
  end;

function TNamedRootAbsenceStub.EvidenceFingerprint: string;
begin
  if Mode = 'empty' then
    Exit('');
  Result := 'stub-named';
end;

function TNamedRootAbsenceStub.IsNameAbsent(const aName: string): Boolean;
begin
  Inc(ImplicitCalls);
  Result := MatchText(aName, ['G', 'fmCreate']);
end;

function TNamedRootAbsenceStub.IsNamedRootMemberAbsent(
  const aRoot: TDelphiSemanticQualifiedRootType; const aSiteUnits: TArray<string>;
  const aName: string): Boolean;
begin
  Inc(NamedCalls);
  Root := aRoot;
  SiteUnits := Copy(aSiteUnits);
  Name := aName;
  if Mode = 'throw' then
    raise EInvalidOpException.Create('Deliberate named witness failure.');
  // These permissive controls expose a lost declaration or site scope in DS.
  // Their expected refusal comes from the retained dcc64 helper cases.
  if Mode = 'property-pair' then
    Exit(SameText(aName, 'ConnectionTimeout') and
      SameText(string.Join('#', aRoot.LookupUnits), 'FireDAC.Comp.Client#FireDAC.ADO.Migrate') and
      (Length(aSiteUnits) = 0));
  if SameText(aName, 'GetLoginUsername') then
    Exit((string.Join('#', aRoot.LookupUnits) <>
      'FireDAC.Comp.Client#FireDAC.DBX.Migrate') or
      (string.Join('#', aSiteUnits) <> 'FireDAC.ADO.Migrate'));
  if SameText(aName, 'ConnectionTimeout') then
    Exit((string.Join('#', aRoot.LookupUnits) <> 'FireDAC.Comp.Client') or
      (string.Join('#', aSiteUnits) <> 'FireDAC.ADO.Migrate'));
  Result := MatchText(aName, ['G', 'fmCreate']);
end;

function TRtlImplicitAbsenceStub.EvidenceFingerprint: string;
begin
  Result := 'ds742-exact-implicit-absence-fixtures-v1';
end;

function TRtlImplicitAbsenceStub.IsNameAbsent(const aName: string): Boolean;
begin
  Result := MatchText(aName, ['G', 'N', 'X', 'S', 'P', 'Hit', 'B']);
end;

function TRtlRootAbsenceStub.EvidenceFingerprint: string;
begin
  Result := 'ds742-exact-absence-fixtures-v1';
end;

function TRtlRootAbsenceStub.IsNameAbsent(const aName: string): Boolean;
begin
  Result := MatchText(aName, ['G', 'N', 'X', 'S', 'P', 'Hit', 'B']);
end;

function TRtlRootAbsenceStub.IsNamedRootMemberAbsent(
  const aRoot: TDelphiSemanticQualifiedRootType; const aSiteUnits: TArray<string>;
  const aName: string): Boolean;
begin
  Result := MatchText(aRoot.Kind, ['class', 'interface']) and
    MatchText(aRoot.TypeName, ['TComponent', 'System.TComponent', 'System.Classes.TComponent',
    'TInterfacedObject', 'System.TInterfacedObject', 'TObject', 'System.TObject', 'System.IInterface']) and
    IsNameAbsent(aName);
end;

constructor TThrowingRootAbsenceProvider.Create(const aMode: string);
begin
  inherited Create;
  fMode := aMode;
end;

function TThrowingRootAbsenceProvider.EvidenceFingerprint: string;
begin
  if fMode = 'fingerprint' then
    raise Exception.Create('Fingerprint unavailable');
  Result := 'review-throwing-provider';
end;

function TThrowingRootAbsenceProvider.IsNameAbsent(const aName: string): Boolean;
begin
  raise Exception.Create('Absence unavailable for ' + aName);
end;

function TImplicitRootAbsenceStub.EvidenceFingerprint: string;
begin
  Result := 'ds712-lPair-LeftOnly-lNearest-stub';
end;

function TImplicitRootAbsenceStub.IsNameAbsent(const aName: string): Boolean;
begin
  Result := SameText(aName, 'lPair') or SameText(aName, 'LeftOnly') or
    SameText(aName, 'lNearest');
end;

procedure TWithBinderTests.NamedRootReceiverMembersUseProviderEvidence(
  const aShape, aMode: string);
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticApiOptions;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lProvider: TNamedRootAbsenceStub;
  lRoot, lUses, lType, lExtra, lBody, lSource, lExpectedRoot: string;
  lExpectedUnits: TArray<string>;
  lPlanned, lInterface: Boolean;
begin
  lRoot := WithBinderTempPath('ds742-named-' + aShape + '-' + aMode);
  TDirectory.CreateDirectory(lRoot);
  lUses := 'System.SysUtils';
  lType := 'class';
  lExtra := '';
  lBody := 'X := G';
  lExpectedRoot := 'System.TObject';
  lExpectedUnits := nil;
  lInterface := MatchText(aShape, ['interface', 'explicit-interface']);
  if aShape = 'closed' then
    lUses := ''
  else if aShape = 'explicit-object' then
  begin
    lType := 'class(TObject)';
    lUses := '';
    lExpectedRoot := 'TObject';
  end else if MatchText(aShape, ['component', 'component-member', 'lookup-shadow']) then
  begin
    lUses := 'System.Classes';
    lType := 'class(TComponent)';
    lExpectedRoot := 'TComponent';
    lExpectedUnits := ['System.Classes'];
    if aShape = 'component-member' then
      lBody := 'X := Tag';
    if aShape = 'lookup-shadow' then
      lExtra := 'TComponent = Integer;'#13#10;
  end else if MatchText(aShape, ['generic-base', 'generic-chain']) then
  begin
    lUses := 'System.Classes, System.Generics.Collections';
    lType := 'class(TList<Integer>)';
    lBody := 'X := G';
    if aShape = 'generic-chain' then
    begin
      lExtra := 'TBase = class(TList<Integer>) end;'#13#10;
      lType := 'class(TBase)';
    end;
  end else if aShape = 'bitmap-order' then
  begin
    lUses := 'Winapi.Windows, Vcl.Graphics';
    lType := 'class(TBitmap)';
    lExpectedRoot := 'TBitmap';
    lExpectedUnits := ['Winapi.Windows', 'Vcl.Graphics'];
  end else if lInterface then
  begin
    lUses := '';
    lType := 'interface';
    lBody := 'G := 7';
    lExpectedRoot := 'System.IInterface';
    if aShape = 'explicit-interface' then
    begin
      lUses := 'System.Classes';
      lExpectedUnits := ['System.Classes'];
      lType := 'interface(IInterface)';
      lExpectedRoot := 'IInterface';
    end;
  end else if aShape = 'exception' then
  begin
    lType := 'class(Exception)';
    lExpectedRoot := 'Exception';
    lExpectedUnits := ['System.SysUtils'];
  end else if aShape = 'obj-unresolved' then
  begin
    lUses := 'System.Classes';
    lBody := 'X := fmCreate';
  end else if aShape = 'site-helper' then
    lExtra := 'THelper = class helper for TObject procedure Extra; end;'#13#10;
  lSource := 'unit NamedUnit;'#13#10'interface'#13#10;
  if aShape = 'implementation' then
    lSource := lSource + 'implementation'#13#10;
  if lUses <> '' then
    lSource := lSource + 'uses ' + lUses + ';'#13#10;
  lSource := lSource + 'type'#13#10 + lExtra + 'TFoo = ' + lType + #13#10;
  if not lInterface then
    lSource := lSource + 'public'#13#10'  X: Integer;'#13#10;
  lSource := lSource + 'end;'#13#10'var'#13#10'  Foo: TFoo;'#13#10'  G: Integer;'#13#10;
  if aShape <> 'implementation' then
    lSource := lSource + 'implementation'#13#10;
  if aShape = 'site-helper' then
    lSource := lSource + 'procedure THelper.Extra; begin end;'#13#10;
  lSource := lSource + 'procedure Run;'#13#10'begin'#13#10'  with Foo do ' + lBody + ';'#13#10 +
    'end;'#13#10'end.'#13#10;
  TFile.WriteAllText(TPath.Combine(lRoot, 'NamedUnit.pas'), lSource, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P; uses NamedUnit; begin end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dproj'),
    '<Project><PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="NamedUnit.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.Combine(lRoot, 'P.dproj');
  lOptions.DelphiVersion := '23.0';
  lProvider := nil;
  if aMode = 'implicit' then
    lOptions.ImplicitRootMemberAbsence := TRtlImplicitAbsenceStub.Create
  else if aMode <> 'missing' then
  begin
    lProvider := TNamedRootAbsenceStub.Create;
    lProvider.Mode := aMode;
    lOptions.ImplicitRootMemberAbsence := lProvider;
  end;
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
  Assert.AreEqual<Integer>(1, Length(lPlan.FinalStatements), aShape);
  lPlanned := ((aMode = 'named') and
    (not MatchText(aShape, ['component-member', 'site-helper', 'lookup-shadow', 'generic-base', 'generic-chain']))) or
    ((aShape = 'closed') and MatchText(aMode, ['implicit', 'throw']));
  if lPlanned then
  begin
    Assert.AreEqual('planned', lPlan.FinalStatements[0].Status, aShape + ': ' +
      lPlan.FinalStatements[0].Reason + '/' + lPlan.FinalStatements[0].SafetyReason);
    if lInterface then
      Assert.AreEqual('  lWithFoo := Foo;'#13#10' G := 7;',
        lPlan.FinalStatements[0].ReplacementText, aShape)
    else
      Assert.AreEqual('  lWithFoo := Foo;'#13#10' lWithFoo.' + lBody + ';',
        lPlan.FinalStatements[0].ReplacementText, aShape);
  end else begin
    Assert.AreEqual('skipped', lPlan.FinalStatements[0].Status, aShape);
    Assert.AreEqual('OWNER_INHERITED_MEMBERS_UNVERIFIED', lPlan.FinalStatements[0].SafetyReason, aShape);
    Assert.AreEqual('', lPlan.FinalStatements[0].ReplacementText, aShape);
    Assert.AreEqual<Integer>(0, Length(lPlan.FinalStatements[0].Edits), aShape);
    Assert.AreEqual<Integer>(0, Length(lPlan.FinalStatements[0].Temps), aShape);
  end;
  if (lProvider <> nil) and (aMode = 'named') then
    if MatchText(aShape, ['site-helper', 'lookup-shadow', 'closed', 'generic-base', 'generic-chain']) then
      Assert.AreEqual(0, lProvider.NamedCalls, aShape)
    else begin
      Assert.IsTrue(lProvider.NamedCalls > 0, aShape);
      Assert.AreEqual(lExpectedRoot, lProvider.Root.TypeName, aShape);
      if MatchText(aShape, ['obj-open', 'obj-unresolved', 'implementation']) then
        lExpectedUnits := lUses.Split([','], TStringSplitOptions.ExcludeEmpty);
      Assert.AreEqual(string.Join('#', lExpectedUnits),
        string.Join('#', lProvider.Root.LookupUnits), aShape);
      Assert.AreEqual(StringReplace(lUses, ', ', '#', [rfReplaceAll]),
        string.Join('#', lProvider.SiteUnits), aShape);
    end;
end;

procedure TWithBinderTests.NamedRootSiteHelperPrecedenceIsPreserved;
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticApiOptions;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lRoot, lSource: string;
begin
  lRoot := WithBinderTempPath('ds742-helper-precedence');
  TDirectory.CreateDirectory(lRoot);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit2.pas'),
    'unit Unit2;'#13#10'interface'#13#10'uses FireDAC.Comp.Client;'#13#10 +
    'type TB = class(TFDConnection)'#13#10'public X: Integer;'#13#10'end;'#13#10 +
    'implementation'#13#10'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit3.pas'),
    'unit Unit3;'#13#10'interface'#13#10'uses Unit2, FireDAC.DBX.Migrate;'#13#10 +
    'type TC = class(TB)'#13#10'public Y: Integer;'#13#10'end;'#13#10 +
    'implementation'#13#10'end.'#13#10, TEncoding.ASCII);
  lSource := 'unit Unit1;'#13#10'interface'#13#10 +
    'uses Unit3, FireDAC.ADO.Migrate;'#13#10'procedure Run;'#13#10 +
    'var C: TC; ConnectionTimeout: Integer;'#13#10'implementation'#13#10 +
    'procedure Run;'#13#10'begin'#13#10 +
    '  with C do Y := ConnectionTimeout;'#13#10'end;'#13#10'end.'#13#10;
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'), lSource, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P; uses Unit1, Unit2, Unit3; begin end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dproj'),
    '<Project><PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="Unit1.pas"/><DCCReference Include="Unit2.pas"/><DCCReference Include="Unit3.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.Combine(lRoot, 'P.dproj');
  lOptions.DelphiVersion := '23.0';
  lOptions.ImplicitRootMemberAbsence := TNamedRootAbsenceStub.Create;
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
  Assert.AreEqual<Integer>(1, Length(lPlan.FinalStatements));
  Assert.AreEqual('skipped', lPlan.FinalStatements[0].Status);
  Assert.AreEqual('OWNER_INHERITED_MEMBERS_UNVERIFIED', lPlan.FinalStatements[0].SafetyReason);
  Assert.AreEqual('', lPlan.FinalStatements[0].ReplacementText);
  Assert.AreEqual<Integer>(0, Length(lPlan.FinalStatements[0].Edits));
  Assert.AreEqual<Integer>(0, Length(lPlan.FinalStatements[0].Temps));
end;

procedure TWithBinderTests.NamedRootCaptureUsesRootMostDeclaration;
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticApiOptions;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lRoot, lSource: string;
begin
  lRoot := WithBinderTempPath('ds742-root-capture');
  TDirectory.CreateDirectory(lRoot);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit2.pas'),
    'unit Unit2;'#13#10'interface'#13#10'uses FireDAC.Comp.Client, FireDAC.DBX.Migrate;'#13#10 +
    'type TB = class(TFDCustomConnection)'#13#10'public X: Integer;'#13#10'end;'#13#10 +
    'implementation'#13#10'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit3.pas'),
    'unit Unit3;'#13#10'interface'#13#10'uses Unit2;'#13#10 +
    'type TC = class(TB)'#13#10'public Y: Integer;'#13#10'end;'#13#10 +
    'implementation'#13#10'end.'#13#10, TEncoding.ASCII);
  lSource := 'unit Unit1;'#13#10'interface'#13#10 +
    'uses Unit3, FireDAC.ADO.Migrate;'#13#10'procedure Run;'#13#10 +
    'var C: TC; GetLoginUsername: Integer;'#13#10'implementation'#13#10 +
    'procedure Run;'#13#10'begin'#13#10 +
    '  with C do Y := GetLoginUsername;'#13#10'end;'#13#10'end.'#13#10;
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'), lSource, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P; uses Unit1, Unit2, Unit3; begin end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dproj'),
    '<Project><PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="Unit1.pas"/><DCCReference Include="Unit2.pas"/><DCCReference Include="Unit3.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.Combine(lRoot, 'P.dproj');
  lOptions.DelphiVersion := '23.0';
  lOptions.ImplicitRootMemberAbsence := TNamedRootAbsenceStub.Create;
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
  Assert.AreEqual<Integer>(1, Length(lPlan.FinalStatements));
  Assert.AreEqual('skipped', lPlan.FinalStatements[0].Status);
  Assert.AreEqual('OWNER_INHERITED_MEMBERS_UNVERIFIED', lPlan.FinalStatements[0].SafetyReason);
  Assert.AreEqual('', lPlan.FinalStatements[0].ReplacementText);
  Assert.AreEqual<Integer>(0, Length(lPlan.FinalStatements[0].Edits));
  Assert.AreEqual<Integer>(0, Length(lPlan.FinalStatements[0].Temps));
end;

procedure TWithBinderTests.NamedRootPrivateGetterPropertyScopes(const aSiteHelper: Boolean);
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticApiOptions;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lProvider: TNamedRootAbsenceStub;
  lRoot, lDeclarationUses, lSiteUses: string;
begin
  lRoot := WithBinderTempPath('ds742-private-getter');
  TDirectory.CreateDirectory(lRoot);
  lDeclarationUses := 'FireDAC.Comp.Client';
  lSiteUses := '';
  if aSiteHelper then
    lSiteUses := ', FireDAC.ADO.Migrate'
  else
    lDeclarationUses := lDeclarationUses + ', FireDAC.ADO.Migrate';
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit2.pas'),
    'unit Unit2;'#13#10'interface'#13#10'uses ' + lDeclarationUses + ';'#13#10 +
    'type TB = class(TFDCustomConnection)'#13#10'public X: Integer;'#13#10'end;'#13#10 +
    'implementation'#13#10'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
    'unit Unit1;'#13#10'interface'#13#10'uses Unit2' + lSiteUses + ';'#13#10 +
    'procedure Run;'#13#10'var C: TB; ConnectionTimeout: Integer;'#13#10 +
    'implementation'#13#10'procedure Run;'#13#10'begin'#13#10 +
    '  with C do X := ConnectionTimeout;'#13#10'end;'#13#10'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P; uses Unit1, Unit2; begin end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dproj'),
    '<Project><PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="Unit1.pas"/><DCCReference Include="Unit2.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.Combine(lRoot, 'P.dproj');
  lOptions.DelphiVersion := '23.0';
  lProvider := TNamedRootAbsenceStub.Create;
  lProvider.Mode := 'property-pair';
  lOptions.ImplicitRootMemberAbsence := lProvider;
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
  Assert.IsTrue(lProvider.NamedCalls > 0, 'The named provider must be exercised.');
  Assert.AreEqual<Integer>(0, lProvider.ImplicitCalls);
  Assert.AreEqual('class', lProvider.Root.Kind);
  Assert.AreEqual('TFDCustomConnection', lProvider.Root.TypeName);
  Assert.AreEqual('ConnectionTimeout', lProvider.Name);
  Assert.AreEqual<Integer>(1, Length(lPlan.FinalStatements));
  if aSiteHelper then
  begin
    Assert.AreEqual('FireDAC.Comp.Client', string.Join('#', lProvider.Root.LookupUnits));
    Assert.AreEqual('FireDAC.ADO.Migrate', string.Join('#', lProvider.SiteUnits));
    Assert.AreEqual('skipped', lPlan.FinalStatements[0].Status);
    Assert.AreEqual('OWNER_INHERITED_MEMBERS_UNVERIFIED', lPlan.FinalStatements[0].SafetyReason);
    Assert.AreEqual('', lPlan.FinalStatements[0].ReplacementText);
    Assert.AreEqual<Integer>(0, Length(lPlan.FinalStatements[0].Edits));
    Assert.AreEqual<Integer>(0, Length(lPlan.FinalStatements[0].Temps));
  end else begin
    Assert.AreEqual('FireDAC.Comp.Client#FireDAC.ADO.Migrate', string.Join('#', lProvider.Root.LookupUnits));
    Assert.AreEqual('', string.Join('#', lProvider.SiteUnits));
    Assert.AreEqual('planned', lPlan.FinalStatements[0].Status);
    Assert.AreEqual('  lWithB := C;'#13#10' lWithB.X := ConnectionTimeout;',
      lPlan.FinalStatements[0].ReplacementText);
  end;
end;

procedure TWithBinderTests.RootProofIncludesUseExpandedScope(const aShape: string);
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticApiOptions;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lProvider: TNamedRootAbsenceStub;
  lRoot, lBase, lDeclarationUses, lSiteUses, lIncludeText: string;
begin
  lRoot := WithBinderTempPath('ds742-include-' + aShape);
  TDirectory.CreateDirectory(lRoot);
  lBase := '';
  lDeclarationUses := '';
  lSiteUses := '';
  lIncludeText := '';
  if aShape <> 'closed' then
  begin
    lBase := '(TFDCustomConnection)';
    lDeclarationUses := 'uses FireDAC.Comp.Client';
    if aShape = 'declaration' then
      lDeclarationUses := lDeclarationUses + '{$I opts.inc}';
    lDeclarationUses := lDeclarationUses + ';'#13#10;
    lIncludeText := ', FireDAC.ADO.Migrate';
    if aShape = 'site' then
      lSiteUses := '{$I opts.inc}';
  end;
  if aShape <> 'unresolved' then
    TFile.WriteAllText(TPath.Combine(lRoot, 'opts.inc'), lIncludeText, TEncoding.ASCII);
  if MatchText(aShape, ['closed', 'unresolved']) then
    lDeclarationUses := '{$I opts.inc}'#13#10 + lDeclarationUses;
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit2.pas'),
    'unit Unit2;'#13#10'interface'#13#10 + lDeclarationUses +
    'type TB = class' + lBase + #13#10'public X: Integer;'#13#10'end;'#13#10 +
    'implementation'#13#10'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
    'unit Unit1;'#13#10'interface'#13#10'uses Unit2' + lSiteUses + ';'#13#10 +
    'procedure Run;'#13#10'var C: TB; G: Integer;'#13#10 +
    'implementation'#13#10'procedure Run;'#13#10'begin'#13#10 +
    '  with C do X := G;'#13#10'end;'#13#10'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P; uses Unit1, Unit2; begin end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dproj'),
    '<Project><PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="Unit1.pas"/><DCCReference Include="Unit2.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.Combine(lRoot, 'P.dproj');
  lOptions.DelphiVersion := '23.0';
  lProvider := TNamedRootAbsenceStub.Create;
  lOptions.ImplicitRootMemberAbsence := lProvider;
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
  Assert.AreEqual<Integer>(1, Length(lPlan.FinalStatements));
  if aShape = 'unresolved' then
  begin
    Assert.AreEqual('skipped', lPlan.FinalStatements[0].Status);
    Assert.AreEqual('receiver-type-not-visible', lPlan.FinalStatements[0].SafetyReason);
    Assert.AreEqual('', lPlan.FinalStatements[0].ReplacementText);
    Assert.AreEqual<Integer>(0, Length(lPlan.FinalStatements[0].Edits));
    Assert.AreEqual<Integer>(0, Length(lPlan.FinalStatements[0].Temps));
    Assert.AreEqual<Integer>(0, lProvider.NamedCalls);
  end else begin
    Assert.AreEqual('planned', lPlan.FinalStatements[0].Status);
    Assert.AreEqual('  lWithB := C;'#13#10' lWithB.X := G;', lPlan.FinalStatements[0].ReplacementText);
    if aShape = 'closed' then
    begin
      Assert.IsTrue(lProvider.ImplicitCalls > 0);
      Assert.AreEqual<Integer>(0, lProvider.NamedCalls);
    end else begin
      Assert.IsTrue(lProvider.NamedCalls > 0);
      Assert.AreEqual('TFDCustomConnection', lProvider.Root.TypeName);
      if aShape = 'declaration' then
      begin
        Assert.AreEqual('FireDAC.Comp.Client#FireDAC.ADO.Migrate', string.Join('#', lProvider.Root.LookupUnits));
        Assert.AreEqual('', string.Join('#', lProvider.SiteUnits));
      end else begin
        Assert.AreEqual('FireDAC.Comp.Client', string.Join('#', lProvider.Root.LookupUnits));
        Assert.AreEqual('FireDAC.ADO.Migrate', string.Join('#', lProvider.SiteUnits));
      end;
    end;
  end;
end;

procedure TWithBinderTests.RootProofRequiresVerifiedPreprocessScope(const aShape: string);
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lLoaded, lStored: TDelphiProjectSnapshot;
  lOptions: TDelphiSemanticApiOptions;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lProvider: TNamedRootAbsenceStub;
  lSession: TDelphiSemanticProjectSessionResult;
  lSessionBuild: TDelphiSemanticRemoveWithPlanBuildResult;
  lRoot, lBase, lName, lDirective, lIncludeText, lSitePrefix, lSiteSuffix, lDeclarationPrefix, lDeclarationSuffix, lShape: string;
  lClosed, lControl, lPlanned: Boolean;
begin
  lRoot := WithBinderTempPath('ds742-verified-preprocess-' + aShape);
  TDirectory.CreateDirectory(lRoot);
  lShape := aShape;
  if StartsText('d-', lShape) then
    lShape[1] := 'n';
  lClosed := StartsText('c-', lShape);
  lControl := MatchText(aShape, ['n-inc-define', 'n-inc-nested', 'n-project-define', 'c-none']);
  lPlanned := aShape = 'c-none';
  lBase := '(TFDCustomConnection)';
  lName := 'ConnectionTimeout';
  if lClosed then
  begin
    lBase := '';
    lName := 'G';
  end;
  lSitePrefix := '';
  lSiteSuffix := '';
  lDirective := '{$IFDEF UNICODE}, FireDAC.ADO.Migrate{$ENDIF}';
  if lClosed then
    lDirective := '{$IFDEF UNICODE}, HiddenHelper{$ENDIF}';
  lIncludeText := lDirective;
  if lShape = 'n-if-compilerversion' then
    lDirective := '{$IF CompilerVersion >= 36.0}, FireDAC.ADO.Migrate{$IFEND}';
  if lShape = 'n-inc-define-unknown' then
  begin
    lSitePrefix := '{$I opts.inc}'#13#10;
    lIncludeText := '{$IFDEF UNICODE}{$DEFINE USE_ADO}{$ENDIF}';
    lDirective := '{$IFDEF USE_ADO}, FireDAC.ADO.Migrate{$ENDIF}';
  end else if lShape = 'n-inc-define' then
  begin
    lSitePrefix := '{$I opts.inc}'#13#10;
    lIncludeText := '{$DEFINE USE_ADO}';
    lDirective := '{$IFDEF USE_ADO}, FireDAC.ADO.Migrate{$ENDIF}';
  end else if lShape = 'n-inc-nested' then
  begin
    lDirective := '{$I opts.inc}';
    lIncludeText := '{$I helper.inc}';
    TFile.WriteAllText(TPath.Combine(lRoot, 'helper.inc'), ', FireDAC.ADO.Migrate', TEncoding.ASCII);
  end else if lShape = 'n-project-define' then
    lDirective := '{$IFDEF USE_ADO}, FireDAC.ADO.Migrate{$ENDIF}'
  else if aShape = 'site-unresolved' then
    lDirective := '{$I missing.inc}'
  else if aShape = 'c-none' then
    lDirective := ''
  else if Pos('-inc-', aShape) > 0 then
    lDirective := '{$I opts.inc}';
  TFile.WriteAllText(TPath.Combine(lRoot, 'opts.inc'), lIncludeText, TEncoding.ASCII);
  lSiteSuffix := lDirective;
  lDeclarationPrefix := '';
  lDeclarationSuffix := '';
  if StartsText('d-', aShape) then
  begin
    lDeclarationPrefix := lSitePrefix;
    lDeclarationSuffix := lSiteSuffix;
    lSitePrefix := '';
    lSiteSuffix := '';
  end;
  lDirective := lDeclarationPrefix + 'uses FireDAC.Comp.Client' + lDeclarationSuffix + ';'#13#10;
  if lClosed then
    lDirective := '';
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit2.pas'),
    'unit Unit2;'#13#10'interface'#13#10 + lDirective +
    'type TB = class' + lBase + #13#10'public X: Integer;'#13#10'end;'#13#10 +
    'implementation'#13#10'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit3.pas'),
    'unit Unit3;'#13#10'interface'#13#10'uses Unit2;'#13#10 +
    'type TC = class(TB)'#13#10'end;'#13#10'implementation'#13#10'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'HiddenHelper.pas'),
    'unit HiddenHelper;'#13#10'interface'#13#10 +
    'type TObjHelper = class helper for TObject'#13#10'function G: Integer;'#13#10'end;'#13#10 +
    'implementation'#13#10'function TObjHelper.G: Integer;'#13#10'begin Result := 5; end;'#13#10'end.'#13#10,
    TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
    'unit Unit1;'#13#10'interface'#13#10 + lSitePrefix + 'uses Unit3' + lSiteSuffix + ';'#13#10 +
    'procedure Run;'#13#10'var C: TC; ' + lName + ': Integer;'#13#10 +
    'implementation'#13#10'procedure Run;'#13#10'begin'#13#10 +
    '  with C do X := ' + lName + ';'#13#10'end;'#13#10'end.'#13#10, TEncoding.ASCII);
  // Diagnostic siblings and helper-declaration scope are independent proof boundaries.
  if MatchText(aShape, ['n-helper-declaration', 'c-helper-declaration']) then
  begin
    lDirective := 'TObject';
    if not lClosed then
      lDirective := 'TFDCustomConnection';
    lSiteSuffix := ', FireDAC.Comp.Client';
    if lClosed then
      lSiteSuffix := '';
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
      'unit Unit1;'#13#10'interface'#13#10'uses Unit3' + lSiteSuffix + ';'#13#10 +
      '{$IFDEF UNICODE}'#13#10'type TLocalHelper = class helper for ' + lDirective + #13#10 +
      'function ' + lName + ': Integer;'#13#10'end;'#13#10'{$ENDIF}'#13#10 +
      'procedure Run;'#13#10'var C: TC; ' + lName + ': Integer;'#13#10 +
      'implementation'#13#10'{$IFDEF UNICODE}'#13#10'function TLocalHelper.' + lName + ': Integer;'#13#10 +
      'begin Result := 5; end;'#13#10'{$ENDIF}'#13#10'procedure Run;'#13#10'begin'#13#10 +
      '  with C do X := ' + lName + ';'#13#10'end;'#13#10'end.'#13#10, TEncoding.ASCII);
  end else if MatchText(aShape, ['n-routine-unicode', 'n-unmatched', 'n-unterminated', 'n-unsupported']) then
  begin
    lDirective := '{$IFDEF UNICODE}C.X := C.X;{$ENDIF}';
    if aShape = 'n-unmatched' then
      lDirective := '{$ENDIF}'
    else if aShape = 'n-unterminated' then
      lDirective := ''
    else if aShape = 'n-unsupported' then
      lDirective := '{$HINTS OFF}';
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
      'unit Unit1;'#13#10'interface'#13#10'uses Unit3;'#13#10 +
      'procedure Run;'#13#10'var C: TC; ConnectionTimeout: Integer;'#13#10 +
      'implementation'#13#10'procedure Run;'#13#10'begin'#13#10 + lDirective + #13#10 +
      '  with C do X := ConnectionTimeout;'#13#10'end;'#13#10'end.'#13#10, TEncoding.ASCII);
    if aShape = 'n-unterminated' then
      TFile.AppendAllText(TPath.Combine(lRoot, 'Unit1.pas'), '{$IFDEF UNICODE}'#13#10, TEncoding.ASCII);
  end;
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P; uses Unit1, Unit2, Unit3; begin end.'#13#10, TEncoding.ASCII);
  lDirective := '';
  if aShape = 'n-project-define' then
    lDirective := '<DCC_Define>USE_ADO</DCC_Define>';
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dproj'),
    '<Project><PropertyGroup><MainSource>P.dpr</MainSource>' + lDirective + '</PropertyGroup>' +
    '<ItemGroup><DCCReference Include="Unit1.pas"/><DCCReference Include="Unit2.pas"/>' +
    '<DCCReference Include="Unit3.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.Combine(lRoot, 'P.dproj');
  lOptions.DelphiVersion := '23.0';
  if lShape = 'n-project-define' then
    lOptions.Defines := ['USE_ADO'];
  lProvider := TNamedRootAbsenceStub.Create;
  lOptions.ImplicitRootMemberAbsence := lProvider;
  // The same proof is consumed by compatibility, both snapshot forms and repeated session routes.
  for var i := 0 to 4 do
  begin
    lProvider.NamedCalls := 0;
    lProvider.ImplicitCalls := 0;
    if i <= 2 then
      lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
    if i = 0 then
      lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts)
    else if i = 1 then
      lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWithCompatibilitySnapshot(lFacts)
    else if i = 2 then
    begin
      lIdentity := Default(TDelphiSemanticSnapshotCacheIdentity);
      lIdentity.CacheKey := 'ds742-preprocess-root-proof';
      lIdentity.IdentityKey := lIdentity.CacheKey;
      lIdentity.SourceFileName := lOptions.ProjectFileName;
      lIdentity.FileHash := lFacts.ContextFingerprint;
      lIdentity.ContextHash := lFacts.ContextFingerprint;
      lIdentity.IncludeGraphHash := lFacts.ContextFingerprint;
      lIdentity.SchemaVersion := 'ds742-preprocess-root-proof';
      lStored := BuildCompatibilityRemoveWithPlanningSnapshotFromFacts(lFacts);
      lCache := TDelphiSemanticSnapshotSqliteCache.Create(TPath.Combine(lRoot, 'standalone.sqlite'));
      try
        lCache.StoreProjectRemoveWithPlanningFacts(lIdentity, lStored, lFacts.Symbols);
        Assert.IsTrue(lCache.TryLoadProjectRemoveWithPlanningFacts(lIdentity, lLoaded));
        try
          lProvider.NamedCalls := 0;
          lProvider.ImplicitCalls := 0;
          lPlan := TDelphiSemanticRemoveWithPlanner.Plan(lLoaded);
        finally
          lLoaded.Free;
        end;
      finally
        lCache.Free;
        lStored.Free;
      end;
    end else begin
      lSession := TDelphiSemanticProjectSession.Open(ProjectOptionsFromApiOptions(lOptions));
      try
        Assert.IsTrue(lSession.Success);
        lSessionBuild := lSession.Session.PlanRemoveWithResult;
        lPlan := lSessionBuild.Plan;
      finally
        lSession.Session.Free;
      end;
    end;
    Assert.AreEqual<Integer>(1, Length(lPlan.FinalStatements), aShape);
    // Native provider evidence is request-local and is not persisted by SQLite.
    if lPlanned and (i <> 2) then
    begin
      Assert.AreEqual('planned', lPlan.FinalStatements[0].Status, aShape);
      Assert.AreEqual('  lWithC := C;'#13#10' lWithC.X := G;',
        lPlan.FinalStatements[0].ReplacementText, aShape);
      Assert.IsTrue(lProvider.ImplicitCalls > 0, aShape);
    end else begin
      Assert.AreEqual('skipped', lPlan.FinalStatements[0].Status, aShape);
      if lPlanned and (i = 2) then
        Assert.AreEqual('symbol-not-found', lPlan.FinalStatements[0].SafetyReason, aShape)
      else
        Assert.AreEqual('OWNER_INHERITED_MEMBERS_UNVERIFIED', lPlan.FinalStatements[0].SafetyReason, aShape);
      Assert.AreEqual('', lPlan.FinalStatements[0].ReplacementText, aShape);
      Assert.AreEqual<Integer>(0, Length(lPlan.FinalStatements[0].Edits), aShape);
      Assert.AreEqual<Integer>(0, Length(lPlan.FinalStatements[0].Temps), aShape);
      if i = 2 then
      begin
        Assert.AreEqual<Integer>(0, lProvider.NamedCalls, aShape);
        Assert.AreEqual<Integer>(0, lProvider.ImplicitCalls, aShape);
      end else if lControl and not lClosed then
      begin
        Assert.IsTrue(lProvider.NamedCalls > 0, aShape);
        Assert.AreEqual('TFDCustomConnection', lProvider.Root.TypeName, aShape);
        Assert.AreEqual('FireDAC.Comp.Client', string.Join('#', lProvider.Root.LookupUnits), aShape);
        Assert.AreEqual('FireDAC.ADO.Migrate', string.Join('#', lProvider.SiteUnits), aShape);
      end else if not lControl then
      begin
        Assert.AreEqual<Integer>(0, lProvider.NamedCalls, aShape);
        Assert.AreEqual<Integer>(0, lProvider.ImplicitCalls, aShape);
      end;
    end;
  end;
end;

procedure TWithBinderTests.FailedModelCannotBypassRootAbsenceProof(const aShape: string);
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lLoaded, lStored: TDelphiProjectSnapshot;
  lOptions: TDelphiSemanticApiOptions;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lProvider: TNamedRootAbsenceStub;
  lSession: TDelphiSemanticProjectSessionResult;
  lSessionBuild: TDelphiSemanticRemoveWithPlanBuildResult;
  lRoot, lDirective, lSitePrefix, lSiteSuffix, lDeclarationPrefix: string;
  lPlanned: Boolean;
begin
  lRoot := WithBinderTempPath('ds742-failed-model-' + aShape);
  TDirectory.CreateDirectory(lRoot);
  lPlanned := aShape = 'n-plain-other-unit';
  lSitePrefix := '';
  lSiteSuffix := ', FireDAC.ADO.Migrate';
  if lPlanned then
    lSiteSuffix := '';
  lDeclarationPrefix := '';
  lDirective := '';
  if aShape = 'n-ifopt' then
    lSiteSuffix := ' {$IFOPT R-}, FireDAC.ADO.Migrate{$ENDIF}'
  else if aShape = 'k-ifopt-site-body' then
    lDirective := '{$IFOPT R+}Writeln(9);{$ENDIF}'#13#10
  else if aShape = 'k-hints-site' then
    lSitePrefix := '{$HINTS OFF}'#13#10
  else if aShape = 'k-inline-site' then
    lSitePrefix := '{$INLINE AUTO}'#13#10
  else if aShape = 'k-hints-unit3' then
    lDeclarationPrefix := '{$HINTS OFF}'#13#10;
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit2.pas'),
    'unit Unit2;'#13#10'interface'#13#10'uses FireDAC.Comp.Client;'#13#10 +
    'type'#13#10'  TB = class(TFDCustomConnection)'#13#10'  public'#13#10'    X: Integer;'#13#10'  end;'#13#10'implementation'#13#10'uses FireDAC.Stan.Def, FireDAC.Stan.Async;'#13#10'end.'#13#10,
    TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit3.pas'),
    'unit Unit3;'#13#10 + lDeclarationPrefix + 'interface'#13#10'uses Unit2;'#13#10 +
    'type'#13#10'  TC = class(TB)'#13#10'  public'#13#10'    Y: Integer;'#13#10'  end;'#13#10 +
    'implementation'#13#10'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
    'unit Unit1;'#13#10 + lSitePrefix + 'interface'#13#10'uses Unit3' + lSiteSuffix + ';'#13#10 +
    'procedure Run;'#13#10'var ConnectionTimeout: Integer = 77;'#13#10 +
    'implementation'#13#10'procedure Run;'#13#10'var C: TC;'#13#10'begin'#13#10 +
    '  C := TC.Create(nil);'#13#10 + lDirective +
    '  with C do Y := ConnectionTimeout;'#13#10'  Writeln(C.Y);'#13#10'end;'#13#10'end.'#13#10,
    TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'OtherUnit.pas'),
    'unit OtherUnit;'#13#10'interface'#13#10'implementation'#13#10 +
    '{$IFOPT R+}{$ENDIF}'#13#10'end.'#13#10, TEncoding.ASCII);
  lDirective := '';
  if MatchText(aShape, ['k-ifopt-other-unit', 'n-plain-other-unit']) then
    lDirective := ', OtherUnit';
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P; uses Unit1, Unit2, Unit3' + lDirective + '; begin Run; end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dproj'),
    '<Project><PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="Unit1.pas"/><DCCReference Include="Unit2.pas"/>' +
    '<DCCReference Include="Unit3.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.Combine(lRoot, 'P.dproj');
  lOptions.DelphiVersion := '23.0';
  lProvider := TNamedRootAbsenceStub.Create;
  lOptions.ImplicitRootMemberAbsence := lProvider;
  // The same proof is consumed by compatibility, both snapshot forms and repeated session routes.
  for var i := 0 to 4 do
  begin
    lProvider.NamedCalls := 0;
    lProvider.ImplicitCalls := 0;
    // Rebuild before each route so provider counts belong to this route, including SQLite input.
    if i <= 2 then
      lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
    // Refusal controls count only planning after the persisted facts have been built.
    if (i = 2) and (not lPlanned) then
    begin
      lProvider.NamedCalls := 0;
      lProvider.ImplicitCalls := 0;
    end;
    if i = 0 then
      lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts)
    else if i = 1 then
      lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWithCompatibilitySnapshot(lFacts)
    else if i = 2 then
    begin
      lIdentity := Default(TDelphiSemanticSnapshotCacheIdentity);
      lIdentity.CacheKey := 'ds742-preprocess-root-proof';
      lIdentity.IdentityKey := lIdentity.CacheKey;
      lIdentity.SourceFileName := lOptions.ProjectFileName;
      lIdentity.FileHash := lFacts.ContextFingerprint;
      lIdentity.ContextHash := lFacts.ContextFingerprint;
      lIdentity.IncludeGraphHash := lFacts.ContextFingerprint;
      lIdentity.SchemaVersion := 'ds742-preprocess-root-proof';
      lStored := BuildCompatibilityRemoveWithPlanningSnapshotFromFacts(lFacts);
      lCache := TDelphiSemanticSnapshotSqliteCache.Create(TPath.Combine(lRoot, 'standalone.sqlite'));
      try
        lCache.StoreProjectRemoveWithPlanningFacts(lIdentity, lStored, lFacts.Symbols);
        Assert.IsTrue(lCache.TryLoadProjectRemoveWithPlanningFacts(lIdentity, lLoaded));
        try
          lPlan := TDelphiSemanticRemoveWithPlanner.Plan(lLoaded);
        finally
          lLoaded.Free;
        end;
      finally
        lCache.Free;
        lStored.Free;
      end;
    end else begin
      lSession := TDelphiSemanticProjectSession.Open(ProjectOptionsFromApiOptions(lOptions));
      try
        Assert.IsTrue(lSession.Success);
        lSessionBuild := lSession.Session.PlanRemoveWithResult;
        lPlan := lSessionBuild.Plan;
      finally
        lSession.Session.Free;
      end;
    end;
    Assert.AreEqual<Integer>(1, Length(lPlan.FinalStatements), aShape);
    if lPlanned then
    begin
      Assert.AreEqual('planned', lPlan.FinalStatements[0].Status, aShape);
      Assert.AreEqual('  lWithC := C;'#13#10' lWithC.Y := ConnectionTimeout;',
        lPlan.FinalStatements[0].ReplacementText, aShape);
      Assert.IsTrue(lProvider.NamedCalls > 0, aShape + ': route ' + IntToStr(i));
      Assert.AreEqual<Integer>(0, lProvider.ImplicitCalls, aShape);
      Assert.AreEqual('TFDCustomConnection', lProvider.Root.TypeName, aShape);
      Assert.AreEqual('FireDAC.Comp.Client', string.Join('#', lProvider.Root.LookupUnits), aShape);
      Assert.AreEqual('', string.Join('#', lProvider.SiteUnits), aShape);
      Assert.AreEqual('ConnectionTimeout', lProvider.Name, aShape);
    end else begin
      Assert.AreEqual('skipped', lPlan.FinalStatements[0].Status, aShape);
      Assert.AreEqual('OWNER_INHERITED_MEMBERS_UNVERIFIED', lPlan.FinalStatements[0].SafetyReason, aShape);
      Assert.AreEqual('', lPlan.FinalStatements[0].ReplacementText, aShape);
      Assert.AreEqual<Integer>(0, Length(lPlan.FinalStatements[0].Edits), aShape);
      Assert.AreEqual<Integer>(0, Length(lPlan.FinalStatements[0].Temps), aShape);
      if i = 2 then
      begin
        Assert.AreEqual<Integer>(0, lProvider.NamedCalls, aShape);
        Assert.AreEqual<Integer>(0, lProvider.ImplicitCalls, aShape);
      end else if not MatchText(aShape, ['k-direct-known', 'k-ifopt-other-unit']) then
      begin
        Assert.AreEqual<Integer>(0, lProvider.NamedCalls, aShape);
        Assert.AreEqual<Integer>(0, lProvider.ImplicitCalls, aShape);
      end;
    end;
  end;
end;

procedure TWithBinderTests.AnonymousRecordRequiresParsedEvidence(const aShape: string);
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lLoaded, lStored: TDelphiProjectSnapshot;
  lOptions: TDelphiSemanticApiOptions;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lSession: TDelphiSemanticProjectSessionResult;
  lSessionBuild: TDelphiSemanticRemoveWithPlanBuildResult;
  lRoot, lSource, lRecord, lSelector, lExpectedReplacement: string;
  lPlanned: Boolean;
begin
  lRoot := WithBinderTempPath('ds742-anonymous-' + aShape);
  TDirectory.CreateDirectory(lRoot);
  lRecord := 'record'#13#10'    Y: Integer;'#13#10;
  if aShape = 'packed-local' then
    lRecord := 'packed ' + lRecord + '    ll: Byte;'#13#10 +
      '    case n_id: AnsiChar of'#13#10 +
      '      #0: (r_b: Byte);'#13#10'      #1: (r_w: Word);'#13#10 +
      '      #2: (r_r: Double)'#13#10;
  if aShape = 'unit-record' then
    lRecord := lRecord + '    fc: Int16;'#13#10 +
      '    ModuleName: array [0..80] of AnsiChar;'#13#10 +
      '    LineNo, Pos: Word;'#13#10'    ErrorChar: Int32;'#13#10;
  if aShape = 'ifopt' then
    lRecord := lRecord + '    {$IFOPT R+}Hidden: Integer;{$ENDIF}'#13#10
  else if aShape = 'ifdef' then
    lRecord := lRecord + '    {$IF Declared(DS742_UNKNOWN_SYMBOL)}Hidden: Integer;{$ENDIF}'#13#10;
  if aShape = 'undefined-symbol' then
    lRecord := lRecord + ' {$IFDEF DS742_UNKNOWN_SYMBOL}Hidden: Integer;{$ENDIF}'#13#10;
  if aShape = 'i-plus' then
    lRecord := lRecord + '    {$I+}'#13#10
  else if aShape = 'i-minus' then
    lRecord := lRecord + '    {$I-}'#13#10;
  if aShape = 'record-comments' then
    lRecord := '{ before packed } packed (* before record *) ' + lRecord;
  if aShape = 'variant' then
    lRecord := lRecord + '    case n_id: AnsiChar of'#13#10 +
      '      #0: (Tag: Integer);'#13#10'      #1: (Other: Integer)'#13#10;
  if aShape = 'packed-local' then
    lRecord := lRecord + '  end absolute Storage;'#13#10
  else
    lRecord := lRecord + '  end;'#13#10;
  lSelector := 'Item';
  lSource := 'unit Unit1;'#13#10'interface'#13#10 +
    'var G, Tag: Integer;'#13#10;
  if aShape = 'failed-model' then
    lSource := lSource + '{$HINTS OFF}'#13#10;
  if MatchText(aShape, ['unit-record', 'failed-model']) then
    lSource := lSource + 'var'#13#10'  Item: ' + lRecord;
  if aShape = 'nested' then
  begin
    lSource := lSource + 'var'#13#10'  Item: record'#13#10 +
      '    Child: ' + lRecord + '  end;'#13#10;
    lSelector := 'Item.Child';
  end;
  if MatchText(aShape, ['named', 'alias']) then
  begin
    lSource := lSource + 'type'#13#10'  TItem = ' + lRecord;
    if aShape = 'alias' then
      lSource := lSource + '  TAlias = TItem;'#13#10;
    // A failed declaring model must never be made anonymous merely because it is a record.
    lSource := lSource + '{$HINTS OFF}'#13#10;
  end;
  lSource := lSource + 'implementation'#13#10'procedure Run;'#13#10;
  if MatchText(aShape, ['named', 'alias']) then
  begin
    if aShape = 'alias' then
      lSource := lSource + 'var Item: TAlias;'#13#10
    else
      lSource := lSource + 'var Item: TItem;'#13#10;
  end else if not MatchText(aShape, ['unit-record', 'failed-model', 'nested']) then
  begin
    lSource := lSource + 'var'#13#10;
    if aShape = 'packed-local' then
      lSource := lSource + '  Storage: array [0..31] of Byte;'#13#10;
    lSource := lSource + '  Item: ' + lRecord;
  end;
  lSource := lSource + 'begin'#13#10'  G := 77;'#13#10'  Tag := 99;'#13#10;
  if aShape = 'variant' then
    lSource := lSource + '  Item.Tag := 5;'#13#10;
  if aShape = 'unit-record' then
    lSource := lSource + '  Item.fc := 5;'#13#10;
  lSource := lSource + '  with ' + lSelector + ' do Y := G';
  if aShape = 'variant' then
    lSource := lSource + ' + Tag';
  if aShape = 'unit-record' then
    lSource := lSource + ' + fc';
  lSource := lSource + ';'#13#10'  Writeln(' + lSelector + '.Y);'#13#10'end;'#13#10'initialization'#13#10'  Run;'#13#10'end.'#13#10;
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'), lSource, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P; uses Unit1; begin end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dproj'),
    '<Project><PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="Unit1.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.Combine(lRoot, 'P.dproj');
  lOptions.DelphiVersion := '23.0';
  lPlanned := MatchText(aShape, ['packed-local', 'unit-record', 'variant', 'i-plus', 'i-minus', 'undefined-symbol']);
  lExpectedReplacement := ' Item.Y := G;';
  if aShape = 'variant' then
    lExpectedReplacement := ' Item.Y := G + Item.Tag;'
  else if aShape = 'unit-record' then
    lExpectedReplacement := ' Item.Y := G + Item.fc;';
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  // The same proof is consumed by compatibility, both snapshot forms and repeated session routes.
  for var i := 0 to 4 do
  begin
    if i = 0 then
      lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts)
    else if i = 1 then
      lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWithCompatibilitySnapshot(lFacts)
    else if i = 2 then
    begin
      lIdentity := Default(TDelphiSemanticSnapshotCacheIdentity);
      lIdentity.CacheKey := 'ds742-preprocess-root-proof';
      lIdentity.IdentityKey := lIdentity.CacheKey;
      lIdentity.SourceFileName := lOptions.ProjectFileName;
      lIdentity.FileHash := lFacts.ContextFingerprint;
      lIdentity.ContextHash := lFacts.ContextFingerprint;
      lIdentity.IncludeGraphHash := lFacts.ContextFingerprint;
      lIdentity.SchemaVersion := 'ds742-preprocess-root-proof';
      lStored := BuildCompatibilityRemoveWithPlanningSnapshotFromFacts(lFacts);
      lCache := TDelphiSemanticSnapshotSqliteCache.Create(TPath.Combine(lRoot, 'standalone.sqlite'));
      try
        lCache.StoreProjectRemoveWithPlanningFacts(lIdentity, lStored, lFacts.Symbols);
        Assert.IsTrue(lCache.TryLoadProjectRemoveWithPlanningFacts(lIdentity, lLoaded), aShape + ': SQLite reload');
        try
          lPlan := TDelphiSemanticRemoveWithPlanner.Plan(lLoaded);
        finally
          lLoaded.Free;
        end;
      finally
        lCache.Free;
        lStored.Free;
      end;
    end else begin
      lSession := TDelphiSemanticProjectSession.Open(ProjectOptionsFromApiOptions(lOptions));
      try
        Assert.IsTrue(lSession.Success, aShape + ': session open');
        lSessionBuild := lSession.Session.PlanRemoveWithResult;
        lPlan := lSessionBuild.Plan;
      finally
        lSession.Session.Free;
      end;
    end;
    Assert.AreEqual<Integer>(1, Length(lPlan.FinalStatements), aShape);
    if lPlanned then
    begin
      Assert.AreEqual('planned', lPlan.FinalStatements[0].Status,
        aShape + ': ' + lPlan.FinalStatements[0].Reason);
      Assert.AreEqual(lExpectedReplacement, lPlan.FinalStatements[0].ReplacementText, aShape);
    end else begin
      Assert.AreEqual('skipped', lPlan.FinalStatements[0].Status, aShape);
      if aShape = 'nested' then
        Assert.AreEqual('receiver-type-not-visible',
          lPlan.FinalStatements[0].SafetyReason, aShape)
      else if aShape = 'record-comments' then
        // This layout is already refused by the binder, independently of absence proof.
        Assert.AreEqual('type-source-not-indexed',
          lPlan.FinalStatements[0].SafetyReason, aShape)
      else if aShape = 'alias' then
        Assert.AreEqual('ALIAS_RECEIVER_MEMBERS_UNVERIFIED',
          lPlan.FinalStatements[0].SafetyReason, aShape)
      else
        Assert.AreEqual('OWNER_INHERITED_MEMBERS_UNVERIFIED',
          lPlan.FinalStatements[0].SafetyReason, aShape);
      Assert.AreEqual('', lPlan.FinalStatements[0].ReplacementText, aShape);
      Assert.AreEqual<Integer>(0, Length(lPlan.FinalStatements[0].Edits), aShape);
      Assert.AreEqual<Integer>(0, Length(lPlan.FinalStatements[0].Temps), aShape);
    end;
  end;
end;

procedure TWithBinderTests.NamedRootProcedureCallsRequireVisibleDeclaration(const aDeclared: Boolean);
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticApiOptions;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lRoot, lSource: string;
begin
  lRoot := WithBinderTempPath('ds742-procedure-' + BoolToStr(aDeclared, True));
  TDirectory.CreateDirectory(lRoot);
  lSource := 'unit NamedUnit;'#13#10'interface'#13#10'uses System.SysUtils;'#13#10 +
    'type TFoo = class public X: Integer; end;'#13#10 +
    'var Foo: TFoo;'#13#10'implementation'#13#10;
  if aDeclared then
    lSource := lSource + 'procedure G(const aValue: Integer); begin Writeln(aValue); end;'#13#10;
  lSource := lSource + 'procedure Run;'#13#10'begin'#13#10'  with Foo do G(X);'#13#10'end;'#13#10'end.'#13#10;
  TFile.WriteAllText(TPath.Combine(lRoot, 'NamedUnit.pas'), lSource, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P; uses NamedUnit; begin end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dproj'),
    '<Project><PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="NamedUnit.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.Combine(lRoot, 'P.dproj');
  lOptions.DelphiVersion := '23.0';
  lOptions.ImplicitRootMemberAbsence := TNamedRootAbsenceStub.Create;
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
  Assert.AreEqual<Integer>(1, Length(lPlan.FinalStatements));
  if aDeclared then
  begin
    Assert.AreEqual('planned', lPlan.FinalStatements[0].Status, lPlan.FinalStatements[0].Reason);
    Assert.AreEqual('  lWithFoo := Foo;'#13#10' G(lWithFoo.X);',
      lPlan.FinalStatements[0].ReplacementText);
  end else begin
    Assert.AreEqual('skipped', lPlan.FinalStatements[0].Status);
    Assert.AreEqual('symbol-not-found', lPlan.FinalStatements[0].Reason);
    Assert.AreEqual('symbol-not-found', lPlan.FinalStatements[0].SafetyReason);
    Assert.AreEqual('', lPlan.FinalStatements[0].ReplacementText);
    Assert.AreEqual<Integer>(0, Length(lPlan.FinalStatements[0].Edits));
    Assert.AreEqual<Integer>(0, Length(lPlan.FinalStatements[0].Temps));
  end;
end;

procedure TWithBinderTests.RootMemberAbsenceProofIsSiteScoped;
var
  lIndex, lOther: TDelphiSemanticRemoveWithLookupIndex;
begin
  lIndex := TDelphiSemanticRemoveWithLookupIndex.Build([], []);
  lIndex.RecordRootMemberAbsence('SiteA', 'RootA', 'G');
  Assert.IsTrue(lIndex.RootMemberAbsenceRecorded('sitea', 'roota', 'g'));
  Assert.IsFalse(lIndex.RootMemberAbsenceRecorded('SiteB', 'RootA', 'G'));
  Assert.IsFalse(lIndex.RootMemberAbsenceRecorded('SiteA', 'RootB', 'G'));
  Assert.IsFalse(lIndex.RootMemberAbsenceRecorded('SiteA', 'RootA', 'Tag'));
  lOther := TDelphiSemanticRemoveWithLookupIndex.Build([], []);
  lOther.AttachValueMemberEvidence(lIndex.ExportValueMemberEvidence);
  Assert.IsFalse(lOther.RootMemberAbsenceRecorded('SiteA', 'RootA', 'G'),
    'Root proofs are request-local and must never be exported or persisted.');
end;

procedure TWithBinderTests.RtlRootReceiverMembersQualifyOrRefuse(const aShape, aMode: string);
var
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lLoaded, lStored: TDelphiProjectSnapshot;
  lOptions: TDelphiSemanticApiOptions;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lRoot, lSource, lExpectedReason: string;
  lExpectedTexts: TArray<string>;
  lExpectedTemps, lExpectedEdits: TArray<Integer>;
  lPlanned: Boolean;
  lStatementIndex: Integer;
  lSession: TDelphiSemanticProjectSessionResult;
  lSessionBuild: TDelphiSemanticRemoveWithPlanBuildResult;
begin
  lRoot := WithBinderTempPath('ds742-' + aShape + '-' + aMode);
  TDirectory.CreateDirectory(lRoot);
  lSource := '';
  if aShape = 'comp-tag-read' then
    lSource := 'unit Unit1;' + #13#10 +
    'interface' + #13#10 +
    'uses System.Classes;' + #13#10 +
    'procedure Run;' + #13#10 +
    'type' + #13#10 +
    ' TFoo = class(TComponent)' + #13#10 +
    ' public' + #13#10 +
    '  X: Integer;' + #13#10 +
    '  S: string;' + #13#10 +
    '  P: TComponent;' + #13#10 +
    ' end;' + #13#10 +
    'var' + #13#10 +
    ' Foo: TFoo;' + #13#10 +
    ' Tag: Integer = 7;' + #13#10 +
    'implementation' + #13#10 +
    'procedure Run;' + #13#10 +
    'begin' + #13#10 +
    ' Foo := TFoo.Create(nil);' + #13#10 +
    ' Foo.Tag := 5;' + #13#10 +
    ' Foo.Name := ''n'';' + #13#10 +
    ' with Foo do X := Tag;' + #13#10 +
    ' Writeln(Foo.X, '' '', Tag);' + #13#10 +
    ' Foo.Free;' + #13#10 +
    'end;' + #13#10 +
    'end.';
  if aShape = 'comp-tag-write' then
    lSource := 'unit Unit1;' + #13#10 +
    'interface' + #13#10 +
    'uses System.Classes;' + #13#10 +
    'procedure Run;' + #13#10 +
    'type' + #13#10 +
    ' TFoo = class(TComponent)' + #13#10 +
    ' public' + #13#10 +
    '  X: Integer;' + #13#10 +
    '  S: string;' + #13#10 +
    '  P: TComponent;' + #13#10 +
    ' end;' + #13#10 +
    'var' + #13#10 +
    ' Foo: TFoo;' + #13#10 +
    ' Tag: Integer = 7;' + #13#10 +
    'implementation' + #13#10 +
    'procedure Run;' + #13#10 +
    'begin' + #13#10 +
    ' Foo := TFoo.Create(nil);' + #13#10 +
    ' Foo.Tag := 5;' + #13#10 +
    ' Foo.Name := ''n'';' + #13#10 +
    ' with Foo do Tag := 3;' + #13#10 +
    ' Writeln(Foo.Tag, '' '', Tag);' + #13#10 +
    ' Foo.Free;' + #13#10 +
    'end;' + #13#10 +
    'end.';
  if aShape = 'comp-name-read' then
    lSource := 'unit Unit1;' + #13#10 +
    'interface' + #13#10 +
    'uses System.Classes;' + #13#10 +
    'procedure Run;' + #13#10 +
    'type' + #13#10 +
    ' TFoo = class(TComponent)' + #13#10 +
    ' public' + #13#10 +
    '  X: Integer;' + #13#10 +
    '  S: string;' + #13#10 +
    '  P: TComponent;' + #13#10 +
    ' end;' + #13#10 +
    'var' + #13#10 +
    ' Foo: TFoo;' + #13#10 +
    ' Name: string = ''g'';' + #13#10 +
    'implementation' + #13#10 +
    'procedure Run;' + #13#10 +
    'begin' + #13#10 +
    ' Foo := TFoo.Create(nil);' + #13#10 +
    ' Foo.Tag := 5;' + #13#10 +
    ' Foo.Name := ''n'';' + #13#10 +
    ' with Foo do S := Name;' + #13#10 +
    ' Writeln(Foo.S, '' '', Name);' + #13#10 +
    ' Foo.Free;' + #13#10 +
    'end;' + #13#10 +
    'end.';
  if aShape = 'comp-owner-read' then
    lSource := 'unit Unit1;' + #13#10 +
    'interface' + #13#10 +
    'uses System.Classes;' + #13#10 +
    'procedure Run;' + #13#10 +
    'type' + #13#10 +
    ' TFoo = class(TComponent)' + #13#10 +
    ' public' + #13#10 +
    '  X: Integer;' + #13#10 +
    '  S: string;' + #13#10 +
    '  P: TComponent;' + #13#10 +
    ' end;' + #13#10 +
    'var' + #13#10 +
    ' Foo: TFoo;' + #13#10 +
    ' Own: TComponent;' + #13#10 +
    ' Owner: TComponent = nil;' + #13#10 +
    'implementation' + #13#10 +
    'procedure Run;' + #13#10 +
    'begin' + #13#10 +
    ' Own := TComponent.Create(nil);' + #13#10 +
    ' Foo := TFoo.Create(Own);' + #13#10 +
    ' with Foo do P := Owner;' + #13#10 +
    ' Writeln(Foo.P = Own);' + #13#10 +
    ' Own.Free;' + #13#10 +
    'end;' + #13#10 +
    'end.';
  if aShape = 'comp-tag-noglobal' then
    lSource := 'unit Unit1;' + #13#10 +
    'interface' + #13#10 +
    'uses System.Classes;' + #13#10 +
    'procedure Run;' + #13#10 +
    'type' + #13#10 +
    ' TFoo = class(TComponent)' + #13#10 +
    ' public' + #13#10 +
    '  X: Integer;' + #13#10 +
    '  S: string;' + #13#10 +
    '  P: TComponent;' + #13#10 +
    ' end;' + #13#10 +
    'var' + #13#10 +
    ' Foo: TFoo;' + #13#10 +
    'implementation' + #13#10 +
    'procedure Run;' + #13#10 +
    'begin' + #13#10 +
    ' Foo := TFoo.Create(nil);' + #13#10 +
    ' Foo.Tag := 5;' + #13#10 +
    ' Foo.Name := ''n'';' + #13#10 +
    ' with Foo do X := Tag;' + #13#10 +
    ' Writeln(Foo.X);' + #13#10 +
    ' Foo.Free;' + #13#10 +
    'end;' + #13#10 +
    'end.';
  if aShape = 'comp-2level-tag' then
    lSource := 'unit Unit1;' + #13#10 +
    'interface' + #13#10 +
    'uses System.Classes;' + #13#10 +
    'procedure Run;' + #13#10 +
    'type' + #13#10 +
    ' TBase = class(TComponent)' + #13#10 +
    ' end;' + #13#10 +
    ' TFoo = class(TBase)' + #13#10 +
    ' public' + #13#10 +
    '  X: Integer;' + #13#10 +
    ' end;' + #13#10 +
    'var' + #13#10 +
    ' Foo: TFoo;' + #13#10 +
    ' Tag: Integer = 7;' + #13#10 +
    'implementation' + #13#10 +
    'procedure Run;' + #13#10 +
    'begin' + #13#10 +
    ' Foo := TFoo.Create(nil);' + #13#10 +
    ' Foo.Tag := 5;' + #13#10 +
    ' with Foo do X := Tag;' + #13#10 +
    ' Writeln(Foo.X, '' '', Tag);' + #13#10 +
    ' Foo.Free;' + #13#10 +
    'end;' + #13#10 +
    'end.';
  if aShape = 'comp-method-call' then
    lSource := 'unit Unit1;' + #13#10 +
    'interface' + #13#10 +
    'uses System.Classes;' + #13#10 +
    'procedure Run;' + #13#10 +
    'procedure DestroyComponents;' + #13#10 +
    'type' + #13#10 +
    ' TFoo = class(TComponent)' + #13#10 +
    ' public' + #13#10 +
    '  X: Integer;' + #13#10 +
    '  S: string;' + #13#10 +
    '  P: TComponent;' + #13#10 +
    ' end;' + #13#10 +
    'var' + #13#10 +
    ' Foo: TFoo;' + #13#10 +
    ' Hit: Integer;' + #13#10 +
    'implementation' + #13#10 +
    'procedure DestroyComponents;' + #13#10 +
    'begin' + #13#10 +
    ' Hit := 1;' + #13#10 +
    'end;' + #13#10 +
    'procedure Run;' + #13#10 +
    'begin' + #13#10 +
    ' Foo := TFoo.Create(nil);' + #13#10 +
    ' Foo.Tag := 5;' + #13#10 +
    ' Foo.Name := ''n'';' + #13#10 +
    ' with Foo do DestroyComponents;' + #13#10 +
    ' Writeln(''hit '', Hit);' + #13#10 +
    ' Foo.Free;' + #13#10 +
    'end;' + #13#10 +
    'end.';
  if aShape = 'intf-refcount' then
    lSource := 'unit Unit1;' + #13#10 +
    'interface' + #13#10 +
    'procedure Run;' + #13#10 +
    'type' + #13#10 +
    ' TBar = class(TInterfacedObject)' + #13#10 +
    ' public' + #13#10 +
    '  X: Integer;' + #13#10 +
    ' end;' + #13#10 +
    'var' + #13#10 +
    ' Bar: TBar;' + #13#10 +
    ' I: IInterface;' + #13#10 +
    ' RefCount: Integer = 7;' + #13#10 +
    'implementation' + #13#10 +
    'procedure Run;' + #13#10 +
    'begin' + #13#10 +
    ' Bar := TBar.Create;' + #13#10 +
    ' I := Bar;' + #13#10 +
    ' with Bar do X := RefCount;' + #13#10 +
    ' Writeln(Bar.X, '' '', RefCount);' + #13#10 +
    ' I := nil;' + #13#10 +
    'end;' + #13#10 +
    'end.';
  if aShape = 'obj-classname-implicit' then
    lSource := 'unit Unit1;' + #13#10 +
    'interface' + #13#10 +
    'procedure Run;' + #13#10 +
    'function ClassName: string;' + #13#10 +
    'type' + #13#10 +
    ' TBaz = class' + #13#10 +
    ' public' + #13#10 +
    '  X: string;' + #13#10 +
    ' end;' + #13#10 +
    'var' + #13#10 +
    ' Baz: TBaz;' + #13#10 +
    'implementation' + #13#10 +
    'function ClassName: string;' + #13#10 +
    'begin' + #13#10 +
    ' Result := ''global'';' + #13#10 +
    'end;' + #13#10 +
    'procedure Run;' + #13#10 +
    'begin' + #13#10 +
    ' Baz := TBaz.Create;' + #13#10 +
    ' with Baz do X := ClassName;' + #13#10 +
    ' Writeln(Baz.X);' + #13#10 +
    ' Baz.Free;' + #13#10 +
    'end;' + #13#10 +
    'end.';
  if aShape = 'obj-classname-explicit' then
    lSource := 'unit Unit1;' + #13#10 +
    'interface' + #13#10 +
    'procedure Run;' + #13#10 +
    'function ClassName: string;' + #13#10 +
    'type' + #13#10 +
    ' TBaz = class(TObject)' + #13#10 +
    ' public' + #13#10 +
    '  X: string;' + #13#10 +
    ' end;' + #13#10 +
    'var' + #13#10 +
    ' Baz: TBaz;' + #13#10 +
    'implementation' + #13#10 +
    'function ClassName: string;' + #13#10 +
    'begin' + #13#10 +
    ' Result := ''global'';' + #13#10 +
    'end;' + #13#10 +
    'procedure Run;' + #13#10 +
    'begin' + #13#10 +
    ' Baz := TBaz.Create;' + #13#10 +
    ' with Baz do X := ClassName;' + #13#10 +
    ' Writeln(Baz.X);' + #13#10 +
    ' Baz.Free;' + #13#10 +
    'end;' + #13#10 +
    'end.';
  if aShape = 'anc-weak-alias-tag' then
    lSource := 'unit Unit1;' + #13#10 +
    'interface' + #13#10 +
    'uses System.Classes;' + #13#10 +
    'procedure Run;' + #13#10 +
    'type' + #13#10 +
    ' TAl = TComponent;' + #13#10 +
    ' TC = class(TAl)' + #13#10 +
    ' public' + #13#10 +
    '  X: Integer;' + #13#10 +
    ' end;' + #13#10 +
    'var' + #13#10 +
    ' C: TC;' + #13#10 +
    ' Tag: Integer = 7;' + #13#10 +
    'implementation' + #13#10 +
    'procedure Run;' + #13#10 +
    'begin' + #13#10 +
    ' C := TC.Create(nil);' + #13#10 +
    ' C.Tag := 5;' + #13#10 +
    ' with C do X := Tag;' + #13#10 +
    ' Writeln(C.X, '' '', Tag);' + #13#10 +
    ' C.Free;' + #13#10 +
    'end;' + #13#10 +
    'end.';
  if aShape = 'anc-strong-alias-tag' then
    lSource := 'unit Unit1;' + #13#10 +
    'interface' + #13#10 +
    'uses System.Classes;' + #13#10 +
    'procedure Run;' + #13#10 +
    'type' + #13#10 +
    ' TAl = type TComponent;' + #13#10 +
    ' TC = class(TAl)' + #13#10 +
    ' public' + #13#10 +
    '  X: Integer;' + #13#10 +
    ' end;' + #13#10 +
    'var' + #13#10 +
    ' C: TC;' + #13#10 +
    ' Tag: Integer = 7;' + #13#10 +
    'implementation' + #13#10 +
    'procedure Run;' + #13#10 +
    'begin' + #13#10 +
    ' C := TC.Create(nil);' + #13#10 +
    ' C.Tag := 5;' + #13#10 +
    ' with C do X := Tag;' + #13#10 +
    ' Writeln(C.X, '' '', Tag);' + #13#10 +
    ' C.Free;' + #13#10 +
    'end;' + #13#10 +
    'end.';
  if aShape = 'nested-outerrec-has-tag' then
    lSource := 'unit Unit1;' + #13#10 +
    'interface' + #13#10 +
    'uses System.Classes;' + #13#10 +
    'procedure Run;' + #13#10 +
    'type' + #13#10 +
    ' TFoo = class(TComponent)' + #13#10 +
    ' public' + #13#10 +
    '  X: Integer;' + #13#10 +
    '  S: string;' + #13#10 +
    '  P: TComponent;' + #13#10 +
    ' end;' + #13#10 +
    ' TRec = record' + #13#10 +
    '  Tag: Integer;' + #13#10 +
    '  B: Integer;' + #13#10 +
    ' end;' + #13#10 +
    'var' + #13#10 +
    ' Foo: TFoo;' + #13#10 +
    ' R: TRec;' + #13#10 +
    'implementation' + #13#10 +
    'procedure Run;' + #13#10 +
    'begin' + #13#10 +
    ' Foo := TFoo.Create(nil);' + #13#10 +
    ' Foo.Tag := 5;' + #13#10 +
    ' Foo.Name := ''n'';' + #13#10 +
    ' R.Tag := 9;' + #13#10 +
    ' with R do' + #13#10 +
    '  with Foo do' + #13#10 +
    '   X := Tag;' + #13#10 +
    ' Writeln(Foo.X);' + #13#10 +
    ' Foo.Free;' + #13#10 +
    'end;' + #13#10 +
    'end.';
  if aShape = 'comp-in-method' then
    lSource := 'unit Unit1;' + #13#10 +
    'interface' + #13#10 +
    'uses System.Classes;' + #13#10 +
    'procedure Run;' + #13#10 +
    'type' + #13#10 +
    ' TFoo = class(TComponent)' + #13#10 +
    ' public' + #13#10 +
    '  X: Integer;' + #13#10 +
    ' end;' + #13#10 +
    ' TOwnerObj = class' + #13#10 +
    '  Tag: Integer;' + #13#10 +
    '  procedure Go(aFoo: TFoo);' + #13#10 +
    ' end;' + #13#10 +
    'implementation' + #13#10 +
    'procedure TOwnerObj.Go(aFoo: TFoo);' + #13#10 +
    'begin' + #13#10 +
    ' with aFoo do X := Tag;' + #13#10 +
    'end;' + #13#10 +
    'procedure Run;' + #13#10 +
    'var' + #13#10 +
    ' Foo: TFoo;' + #13#10 +
    ' O: TOwnerObj;' + #13#10 +
    'begin' + #13#10 +
    ' Foo := TFoo.Create(nil);' + #13#10 +
    ' Foo.Tag := 5;' + #13#10 +
    ' O := TOwnerObj.Create;' + #13#10 +
    ' O.Tag := 7;' + #13#10 +
    ' O.Go(Foo);' + #13#10 +
    ' Writeln(Foo.X);' + #13#10 +
    ' O.Free;' + #13#10 +
    ' Foo.Free;' + #13#10 +
    'end;' + #13#10 +
    'end.';
  if aShape = 'alias-projclass-classname' then
    lSource := 'unit Unit1;' + #13#10 +
    'interface' + #13#10 +
    'procedure Run;' + #13#10 +
    'function ClassName: string;' + #13#10 +
    'type' + #13#10 +
    ' TK = class' + #13#10 +
    ' public' + #13#10 +
    '  X: string;' + #13#10 +
    ' end;' + #13#10 +
    ' TKA = TK;' + #13#10 +
    'var' + #13#10 +
    ' K: TKA;' + #13#10 +
    'implementation' + #13#10 +
    'function ClassName: string;' + #13#10 +
    'begin' + #13#10 +
    ' Result := ''global'';' + #13#10 +
    'end;' + #13#10 +
    'procedure Run;' + #13#10 +
    'begin' + #13#10 +
    ' K := TKA.Create;' + #13#10 +
    ' with K do X := ClassName;' + #13#10 +
    ' Writeln(K.X);' + #13#10 +
    ' K.Free;' + #13#10 +
    'end;' + #13#10 +
    'end.';
  if aShape = 'sr-excludeattr' then
    lSource := 'unit Unit1;' + #13#10 +
    'interface' + #13#10 +
    'uses System.SysUtils;' + #13#10 +
    'procedure Run;' + #13#10 +
    'type' + #13#10 +
    ' TMySR = TSearchRec;' + #13#10 +
    'var' + #13#10 +
    ' SR: TMySR;' + #13#10 +
    ' X: Integer;' + #13#10 +
    ' S: string;' + #13#10 +
    ' ExcludeAttr: Integer = 7;' + #13#10 +
    'implementation' + #13#10 +
    'procedure Run;' + #13#10 +
    'begin' + #13#10 +
    ' SR.ExcludeAttr := 5;' + #13#10 +
    ' with SR do X := ExcludeAttr;' + #13#10 +
    ' Writeln(X, '' '', ExcludeAttr);' + #13#10 +
    'end;' + #13#10 +
    'end.';
  if aShape = 'sr-findhandle' then
    lSource := 'unit Unit1;' + #13#10 +
    'interface' + #13#10 +
    'uses System.SysUtils;' + #13#10 +
    'procedure Run;' + #13#10 +
    'type' + #13#10 +
    ' TMySR = TSearchRec;' + #13#10 +
    'var' + #13#10 +
    ' SR: TMySR;' + #13#10 +
    ' X: Integer;' + #13#10 +
    ' S: string;' + #13#10 +
    ' FindHandle: Integer = 7;' + #13#10 +
    'implementation' + #13#10 +
    'procedure Run;' + #13#10 +
    'begin' + #13#10 +
    ' SR.FindHandle := 5;' + #13#10 +
    ' with SR do X := FindHandle;' + #13#10 +
    ' Writeln(X, '' '', FindHandle);' + #13#10 +
    'end;' + #13#10 +
    'end.';
  if aShape = 'sr-finddata' then
    lSource := 'unit Unit1;' + #13#10 +
    'interface' + #13#10 +
    'uses System.SysUtils;' + #13#10 +
    'procedure Run;' + #13#10 +
    'type' + #13#10 +
    ' TMySR = TSearchRec;' + #13#10 +
    'var' + #13#10 +
    ' SR: TMySR;' + #13#10 +
    ' X: Integer;' + #13#10 +
    ' S: string;' + #13#10 +
    ' FindData: record dwFileAttributes: Integer; end;' + #13#10 +
    'implementation' + #13#10 +
    'procedure Run;' + #13#10 +
    'begin' + #13#10 +
    ' SR.FindData.dwFileAttributes := 5;' + #13#10 +
    ' with SR do X := FindData.dwFileAttributes;' + #13#10 +
    ' Writeln(X, '' '', FindData.dwFileAttributes);' + #13#10 +
    'end;' + #13#10 +
    'end.';
  if aShape = 'sr-finddata-fillchar' then
    lSource := 'unit Unit1;' + #13#10 +
    'interface' + #13#10 +
    'uses System.SysUtils;' + #13#10 +
    'procedure Run;' + #13#10 +
    'type' + #13#10 +
    ' TMySR = TSearchRec;' + #13#10 +
    'var' + #13#10 +
    ' SR: TMySR;' + #13#10 +
    ' X: Integer;' + #13#10 +
    ' S: string;' + #13#10 +
    ' FindData: record dwFileAttributes: Integer; end = (dwFileAttributes: 7);' + #13#10 +
    'implementation' + #13#10 +
    'procedure Run;' + #13#10 +
    'begin' + #13#10 +
    ' SR.FindData.dwFileAttributes := 5;' + #13#10 +
    ' with SR do FillChar(FindData, SizeOf(FindData), 0);' + #13#10 +
    ' Writeln(SR.FindData.dwFileAttributes, '' '', FindData.dwFileAttributes);' + #13#10 +
    'end;' + #13#10 +
    'end.';
  if aShape = 'sr-timestamp' then
    lSource := 'unit Unit1;' + #13#10 +
    'interface' + #13#10 +
    'uses System.SysUtils;' + #13#10 +
    'procedure Run;' + #13#10 +
    'type' + #13#10 +
    ' TMySR = TSearchRec;' + #13#10 +
    'var' + #13#10 +
    ' SR: TMySR;' + #13#10 +
    ' X: Integer;' + #13#10 +
    ' S: string;' + #13#10 +
    ' TimeStamp: Integer = 7;' + #13#10 +
    'implementation' + #13#10 +
    'procedure Run;' + #13#10 +
    'begin' + #13#10 +
    ' with SR do X := Ord(TimeStamp = 7);' + #13#10 +
    ' Writeln(X);' + #13#10 +
    'end;' + #13#10 +
    'end.';
  if aShape = 'ctl-comp-own-member' then
    lSource := 'unit Unit1;' + #13#10 +
    'interface' + #13#10 +
    'uses System.Classes;' + #13#10 +
    'procedure Run;' + #13#10 +
    'type' + #13#10 +
    ' TFoo = class(TComponent)' + #13#10 +
    ' public' + #13#10 +
    '  X: Integer;' + #13#10 +
    '  S: string;' + #13#10 +
    '  P: TComponent;' + #13#10 +
    ' end;' + #13#10 +
    'var' + #13#10 +
    ' Foo: TFoo;' + #13#10 +
    'implementation' + #13#10 +
    'procedure Run;' + #13#10 +
    'begin' + #13#10 +
    ' Foo := TFoo.Create(nil);' + #13#10 +
    ' Foo.Tag := 5;' + #13#10 +
    ' Foo.Name := ''n'';' + #13#10 +
    ' with Foo do X := 7;' + #13#10 +
    ' Writeln(Foo.X);' + #13#10 +
    ' Foo.Free;' + #13#10 +
    'end;' + #13#10 +
    'end.';
  if aShape = 'ctl-obj-own-member' then
    lSource := 'unit Unit1;' + #13#10 +
    'interface' + #13#10 +
    'procedure Run;' + #13#10 +
    'type' + #13#10 +
    ' TBaz = class' + #13#10 +
    ' public' + #13#10 +
    '  X: string;' + #13#10 +
    ' end;' + #13#10 +
    'var' + #13#10 +
    ' Baz: TBaz;' + #13#10 +
    'implementation' + #13#10 +
    'procedure Run;' + #13#10 +
    'begin' + #13#10 +
    ' Baz := TBaz.Create;' + #13#10 +
    ' with Baz do X := ''m'';' + #13#10 +
    ' Writeln(Baz.X);' + #13#10 +
    ' Baz.Free;' + #13#10 +
    'end;' + #13#10 +
    'end.';
  if aShape = 'ctl-record-absent-global' then
    lSource := 'unit Unit1;' + #13#10 +
    'interface' + #13#10 +
    'procedure Run;' + #13#10 +
    'type' + #13#10 +
    ' TRec = record' + #13#10 +
    '  A: Integer;' + #13#10 +
    ' end;' + #13#10 +
    'var' + #13#10 +
    ' R: TRec;' + #13#10 +
    ' G: Integer = 9;' + #13#10 +
    'implementation' + #13#10 +
    'procedure Run;' + #13#10 +
    'begin' + #13#10 +
    ' with R do A := G;' + #13#10 +
    ' Writeln(R.A);' + #13#10 +
    'end;' + #13#10 +
    'end.';
  if aShape = 'ctl-alias-projrec-field' then
    lSource := 'unit Unit1;' + #13#10 +
    'interface' + #13#10 +
    'procedure Run;' + #13#10 +
    'type' + #13#10 +
    ' TItem = record' + #13#10 +
    '  A: Integer;' + #13#10 +
    ' end;' + #13#10 +
    ' TAlias = TItem;' + #13#10 +
    'var' + #13#10 +
    ' Item: TAlias;' + #13#10 +
    ' G: Integer = 9;' + #13#10 +
    'implementation' + #13#10 +
    'procedure Run;' + #13#10 +
    'begin' + #13#10 +
    ' with Item do A := G;' + #13#10 +
    ' Writeln(Item.A);' + #13#10 +
    'end;' + #13#10 +
    'end.';
  if aShape = 'nested-innerrec-tag-ctl' then
    lSource := 'unit Unit1;' + #13#10 +
    'interface' + #13#10 +
    'uses System.Classes;' + #13#10 +
    'procedure Run;' + #13#10 +
    'type' + #13#10 +
    ' TFoo = class(TComponent)' + #13#10 +
    ' public' + #13#10 +
    '  X: Integer;' + #13#10 +
    '  S: string;' + #13#10 +
    '  P: TComponent;' + #13#10 +
    ' end;' + #13#10 +
    ' TRec = record' + #13#10 +
    '  Tag: Integer;' + #13#10 +
    '  B: Integer;' + #13#10 +
    ' end;' + #13#10 +
    'var' + #13#10 +
    ' Foo: TFoo;' + #13#10 +
    ' R: TRec;' + #13#10 +
    'implementation' + #13#10 +
    'procedure Run;' + #13#10 +
    'begin' + #13#10 +
    ' Foo := TFoo.Create(nil);' + #13#10 +
    ' Foo.Tag := 5;' + #13#10 +
    ' Foo.Name := ''n'';' + #13#10 +
    ' R.Tag := 9;' + #13#10 +
    ' with Foo do' + #13#10 +
    '  with R do' + #13#10 +
    '   B := Tag;' + #13#10 +
    ' Writeln(R.B);' + #13#10 +
    ' Foo.Free;' + #13#10 +
    'end;' + #13#10 +
    'end.';
  if aShape = 'ctl-rec-in-comp-method-free' then
    lSource := 'unit Unit1;' + #13#10 +
    'interface' + #13#10 +
    'uses System.Classes;' + #13#10 +
    'procedure Run;' + #13#10 +
    'type' + #13#10 +
    ' TFoo = class(TComponent)' + #13#10 +
    ' public' + #13#10 +
    '  X: Integer;' + #13#10 +
    '  S: string;' + #13#10 +
    '  P: TComponent;' + #13#10 +
    ' end;' + #13#10 +
    ' TRec = record' + #13#10 +
    '  B: Integer;' + #13#10 +
    ' end;' + #13#10 +
    'var' + #13#10 +
    ' Foo: TFoo;' + #13#10 +
    ' R: TRec;' + #13#10 +
    'implementation' + #13#10 +
    'procedure Run;' + #13#10 +
    'begin' + #13#10 +
    ' Foo := TFoo.Create(nil);' + #13#10 +
    ' Foo.Tag := 5;' + #13#10 +
    ' Foo.Name := ''n'';' + #13#10 +
    ' with R do B := Foo.Tag;' + #13#10 +
    ' Writeln(R.B);' + #13#10 +
    ' Foo.Free;' + #13#10 +
    'end;' + #13#10 +
    'end.';
  if aShape = 'sr-name-ctl' then
    lSource := 'unit Unit1;' + #13#10 +
    'interface' + #13#10 +
    'uses System.SysUtils;' + #13#10 +
    'procedure Run;' + #13#10 +
    'type' + #13#10 +
    ' TMySR = TSearchRec;' + #13#10 +
    'var' + #13#10 +
    ' SR: TMySR;' + #13#10 +
    ' X: Integer;' + #13#10 +
    ' S: string;' + #13#10 +
    'implementation' + #13#10 +
    'procedure Run;' + #13#10 +
    'begin' + #13#10 +
    ' SR.Name := ''n'';' + #13#10 +
    ' with SR do S := Name;' + #13#10 +
    ' Writeln(S);' + #13#10 +
    'end;' + #13#10 +
    'end.';
  if aShape = 'sr-fileio715' then
    lSource := 'unit Unit1;' + #13#10 +
    'interface' + #13#10 +
    'uses System.SysUtils;' + #13#10 +
    'procedure Run;' + #13#10 +
    'type' + #13#10 +
    ' TMySR = TSearchRec;' + #13#10 +
    'var' + #13#10 +
    ' SR: TMySR;' + #13#10 +
    ' X: Integer;' + #13#10 +
    ' S: string;' + #13#10 +
    'implementation' + #13#10 +
    'procedure Run;' + #13#10 +
    'begin' + #13#10 +
    ' SR.Name := ''n''; SR.Size := 3; SR.Attr := 1;' + #13#10 +
    ' with SR do' + #13#10 +
    ' begin' + #13#10 +
    '  S := Name;' + #13#10 +
    '  X := Size + Attr;' + #13#10 +
    ' end;' + #13#10 +
    ' Writeln(S, '' '', X);' + #13#10 +
    'end;' + #13#10 +
    'end.';
  if aShape = 'ctl-obj-absent-global' then
    lSource := 'unit Unit1;' + #13#10 +
    'interface' + #13#10 +
    'procedure Run;' + #13#10 +
    'type' + #13#10 +
    ' TBaz = class' + #13#10 +
    ' public' + #13#10 +
    '  X: string;' + #13#10 +
    ' end;' + #13#10 +
    'var' + #13#10 +
    ' Baz: TBaz;' + #13#10 +
    ' G: string = ''g'';' + #13#10 +
    'implementation' + #13#10 +
    'procedure Run;' + #13#10 +
    'begin' + #13#10 +
    ' Baz := TBaz.Create;' + #13#10 +
    ' with Baz do X := G;' + #13#10 +
    ' Writeln(Baz.X);' + #13#10 +
    ' Baz.Free;' + #13#10 +
    'end;' + #13#10 +
    'end.';
  if aShape = 'obj-local-var-ctl' then
    lSource := 'unit Unit1;' + #13#10 +
    'interface' + #13#10 +
    'procedure Run;' + #13#10 +
    'type' + #13#10 +
    ' TBaz = class' + #13#10 +
    ' public' + #13#10 +
    '  X: Integer;' + #13#10 +
    ' end;' + #13#10 +
    'implementation' + #13#10 +
    'procedure Run;' + #13#10 +
    'var' + #13#10 +
    ' Baz: TBaz;' + #13#10 +
    ' N: Integer;' + #13#10 +
    'begin' + #13#10 +
    ' N := 3;' + #13#10 +
    ' Baz := TBaz.Create;' + #13#10 +
    ' with Baz do X := N;' + #13#10 +
    ' Writeln(Baz.X);' + #13#10 +
    ' Baz.Free;' + #13#10 +
    'end;' + #13#10 +
    'end.';
  if aShape = 'ctl-comp-absent-global' then
    lSource := 'unit Unit1;' + #13#10 +
    'interface' + #13#10 +
    'uses System.Classes;' + #13#10 +
    'procedure Run;' + #13#10 +
    'type' + #13#10 +
    ' TFoo = class(TComponent)' + #13#10 +
    ' public' + #13#10 +
    '  X: Integer;' + #13#10 +
    '  S: string;' + #13#10 +
    '  P: TComponent;' + #13#10 +
    ' end;' + #13#10 +
    'var' + #13#10 +
    ' Foo: TFoo;' + #13#10 +
    ' G: Integer = 9;' + #13#10 +
    'implementation' + #13#10 +
    'procedure Run;' + #13#10 +
    'begin' + #13#10 +
    ' Foo := TFoo.Create(nil);' + #13#10 +
    ' Foo.Tag := 5;' + #13#10 +
    ' Foo.Name := ''n'';' + #13#10 +
    ' with Foo do X := G;' + #13#10 +
    ' Writeln(Foo.X);' + #13#10 +
    ' Foo.Free;' + #13#10 +
    'end;' + #13#10 +
    'end.';
  if aShape = 'comp-local-var' then
    lSource := 'unit Unit1;' + #13#10 +
    'interface' + #13#10 +
    'uses System.Classes;' + #13#10 +
    'procedure Run;' + #13#10 +
    'type' + #13#10 +
    ' TFoo = class(TComponent)' + #13#10 +
    ' public' + #13#10 +
    '  X: Integer;' + #13#10 +
    ' end;' + #13#10 +
    'implementation' + #13#10 +
    'procedure Run;' + #13#10 +
    'var' + #13#10 +
    ' Foo: TFoo;' + #13#10 +
    ' N: Integer;' + #13#10 +
    'begin' + #13#10 +
    ' N := 3;' + #13#10 +
    ' Foo := TFoo.Create(nil);' + #13#10 +
    ' with Foo do X := N;' + #13#10 +
    ' Writeln(Foo.X);' + #13#10 +
    ' Foo.Free;' + #13#10 +
    'end;' + #13#10 +
    'end.';
  if aShape = 'comp-same-name-field-ctl' then
    lSource := 'unit Unit1;' + #13#10 +
    'interface' + #13#10 +
    'uses System.Classes;' + #13#10 +
    'procedure Run;' + #13#10 +
    'type' + #13#10 +
    ' TFoo = class(TComponent)' + #13#10 +
    ' public' + #13#10 +
    '  Tag: Integer;' + #13#10 +
    ' end;' + #13#10 +
    'var' + #13#10 +
    ' Foo: TFoo;' + #13#10 +
    ' X: Integer;' + #13#10 +
    ' Tag: Integer = 7;' + #13#10 +
    'implementation' + #13#10 +
    'procedure Run;' + #13#10 +
    'begin' + #13#10 +
    ' Foo := TFoo.Create(nil);' + #13#10 +
    ' Foo.Tag := 5;' + #13#10 +
    ' with Foo do X := Tag;' + #13#10 +
    ' Writeln(X);' + #13#10 +
    ' Foo.Free;' + #13#10 +
    'end;' + #13#10 +
    'end.';
  if aShape = 'nested-outerrec-field-b' then
    lSource := 'unit Unit1;' + #13#10 +
    'interface' + #13#10 +
    'uses System.Classes;' + #13#10 +
    'procedure Run;' + #13#10 +
    'type' + #13#10 +
    ' TFoo = class(TComponent)' + #13#10 +
    ' public' + #13#10 +
    '  X: Integer;' + #13#10 +
    '  S: string;' + #13#10 +
    '  P: TComponent;' + #13#10 +
    ' end;' + #13#10 +
    ' TRec = record' + #13#10 +
    '  Tag: Integer;' + #13#10 +
    '  B: Integer;' + #13#10 +
    ' end;' + #13#10 +
    'var' + #13#10 +
    ' Foo: TFoo;' + #13#10 +
    ' R: TRec;' + #13#10 +
    'implementation' + #13#10 +
    'procedure Run;' + #13#10 +
    'begin' + #13#10 +
    ' Foo := TFoo.Create(nil);' + #13#10 +
    ' Foo.Tag := 5;' + #13#10 +
    ' Foo.Name := ''n'';' + #13#10 +
    ' with R do' + #13#10 +
    '  with Foo do' + #13#10 +
    '   B := 4;' + #13#10 +
    ' Writeln(R.B);' + #13#10 +
    ' Foo.Free;' + #13#10 +
    'end;' + #13#10 +
    'end.';
  if MatchText(aShape, ['nested-inner-tag', 'nested-inner-absent-ctl']) then
    lSource := 'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses System.Classes;'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TFoo = class(TComponent)'#13#10 +
      '  public'#13#10 +
      '   X: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TBar = class(TComponent)'#13#10 +
      '  public'#13#10 +
      '   Y: Integer;'#13#10 +
      ' end;'#13#10 +
      'var'#13#10 +
      '  Foo: TFoo;'#13#10 +
      '  Bar: TBar;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' Foo := TFoo.Create(nil);'#13#10 +
      ' Foo.Tag := 5;'#13#10 +
      ' Bar := TBar.Create(nil);'#13#10 +
      ' Bar.Tag := 9;'#13#10 +
      ' with Foo do'#13#10 +
      '  with Bar do'#13#10 +
      '   Y := Tag;'#13#10 +
      ' Writeln(Bar.Y);'#13#10 +
      'end;'#13#10 +
      'end.';
  if aShape = 'nested-inner-absent-ctl' then
  begin
    lSource := StringReplace(lSource, ' Bar: TBar;', ' Bar: TBar;'#13#10' G: Integer = 7;', []);
    lSource := StringReplace(lSource, ' with Foo do'#13#10'  with Bar do'#13#10'   Y := Tag;',
      ' with Foo do begin X := Tag;'#13#10'  with Bar do Y := G; end;', []);
    lSource := StringReplace(lSource, 'Bar', 'B', [rfReplaceAll]);
    lSource := StringReplace(lSource, ' TFoo = class(TComponent)'#13#10'  public',
      ' TFoo = record'#13#10' Tag: Integer;', []);
    lSource := StringReplace(lSource, 'Foo := TFoo.Create(nil)', 'Foo := Default(TFoo)', []);
  end;
  Assert.AreNotEqual('', lSource, aShape);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'), lSource, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P; uses Unit1; begin Run; end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dproj'),
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="Unit1.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.Combine(lRoot, 'P.dproj');
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win64';
  lOptions.DelphiVersion := '23.0';
  lOptions.Cache.SqliteCacheFileName := TPath.Combine(lRoot, 'cache.sqlite');
  if MatchText(aMode, ['rootcold', 'namedcold']) or (aShape = 'nested-inner-absent-ctl') then
    lOptions.ImplicitRootMemberAbsence := TRtlRootAbsenceStub.Create;
  if aMode = 'rootcold' then
    lOptions.ImplicitRootMemberAbsence := TRtlImplicitAbsenceStub.Create;
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
  if aMode = 'snapshot' then
    lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWithCompatibilitySnapshot(lFacts);
  if aMode = 'standalone' then
  begin
    lIdentity := Default(TDelphiSemanticSnapshotCacheIdentity);
    lIdentity.CacheKey := 'ds742-root-evidence';
    lIdentity.IdentityKey := lIdentity.CacheKey;
    lIdentity.SourceFileName := lOptions.ProjectFileName;
    lIdentity.FileHash := lFacts.ContextFingerprint;
    lIdentity.ContextHash := lFacts.ContextFingerprint;
    lIdentity.IncludeGraphHash := 'no-includes';
    lIdentity.SchemaVersion := 'ds742-root-evidence';
    lStored := BuildCompatibilityRemoveWithPlanningSnapshotFromFacts(lFacts);
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(TPath.Combine(lRoot, 'standalone.sqlite'));
    try
      lCache.StoreProjectRemoveWithPlanningFacts(lIdentity, lStored, lFacts.Symbols);
      Assert.IsTrue(lCache.TryLoadProjectRemoveWithPlanningFacts(lIdentity, lLoaded));
      try
        lPlan := TDelphiSemanticRemoveWithPlanner.Plan(lLoaded);
      finally
        lLoaded.Free;
      end;
    finally
      lCache.Free;
      lStored.Free;
    end;
  end;
  if MatchText(aMode, ['sessioncold', 'sessionwarm']) then
    for var i := 0 to Ord(aMode = 'sessionwarm') do
    begin
      lSession := TDelphiSemanticProjectSession.Open(ProjectOptionsFromApiOptions(lOptions));
      try
        Assert.IsTrue(lSession.Success);
        lSessionBuild := lSession.Session.PlanRemoveWithResult;
        if aShape = 'nested-inner-absent-ctl' then
        Assert.AreEqual(0, Integer(lSessionBuild.SnapshotMetrics.SnapshotCacheHits))
      else
        Assert.AreEqual(i, Integer(lSessionBuild.SnapshotMetrics.SnapshotCacheHits));
        lPlan := lSessionBuild.Plan;
      finally
        lSession.Session.Free;
      end;
    end;
  if aShape = 'nested-inner-absent-ctl' then
  begin
    Assert.AreEqual(1, Integer(Length(lPlan.FinalStatements)));
    Assert.AreEqual('planned', lPlan.FinalStatements[0].Status,
      lPlan.FinalStatements[0].Reason + ':' + lPlan.FinalStatements[0].SafetyReason);
    Assert.AreEqual('', lPlan.FinalStatements[0].SafetyReason);
    Assert.AreEqual(' lWithFooPtr := @Foo;'#13#10 +
      ' begin lWithFooPtr^.X := lWithFooPtr^.Tag;'#13#10 +
      '    lWithB := B;'#13#10' lWithB.Y := G; end;',
      lPlan.FinalStatements[0].ReplacementText);
    Assert.AreEqual(2, Integer(Length(lPlan.FinalStatements[0].Temps)));
    Assert.AreEqual(2, Integer(Length(lPlan.FinalStatements[0].Edits)));
    Exit;
  end;
  lPlanned := MatchText(aShape, ['ctl-comp-own-member', 'ctl-obj-own-member', 'ctl-record-absent-global', 'ctl-alias-projrec-field', 'nested-innerrec-tag-ctl', 'ctl-rec-in-comp-method-free', 'sr-name-ctl', 'sr-fileio715']);
  lPlanned := lPlanned or (MatchText(aShape, ['ctl-obj-absent-global', 'obj-local-var-ctl']) and MatchText(aMode, ['rootcold', 'namedcold']));
  lPlanned := lPlanned or (MatchText(aShape, ['ctl-comp-absent-global', 'comp-local-var', 'comp-same-name-field-ctl', 'nested-outerrec-field-b']) and (aMode = 'namedcold'));
  if lPlanned then
  begin
    if aShape = 'ctl-comp-own-member' then
    begin
      lExpectedTexts := [' lWithFoo := Foo;' + #13#10 +
    ' lWithFoo.X := 7;'];
      lExpectedTemps := [1];
      lExpectedEdits := [2];
    end;
    if aShape = 'ctl-obj-own-member' then
    begin
      lExpectedTexts := [' lWithBaz := Baz;' + #13#10 +
    ' lWithBaz.X := ''m'';'];
      lExpectedTemps := [1];
      lExpectedEdits := [2];
    end;
    if aShape = 'ctl-record-absent-global' then
    begin
      lExpectedTexts := [' lWithRecPtr := @R;' + #13#10 +
    ' lWithRecPtr^.A := G;'];
      lExpectedTemps := [1];
      lExpectedEdits := [2];
    end;
    if aShape = 'ctl-alias-projrec-field' then
    begin
      lExpectedTexts := [' Item.A := G;'];
      lExpectedTemps := [0];
      lExpectedEdits := [1];
    end;
    if aShape = 'nested-innerrec-tag-ctl' then
    begin
      lExpectedTexts := [' lWithFoo := Foo;' + #13#10 +
    '   begin' + #13#10 +
    '    lWithRecPtr := @R;' + #13#10 +
    '   lWithRecPtr^.B := lWithRecPtr^.Tag;' + #13#10 +
    '  end;'];
      lExpectedTemps := [2];
      lExpectedEdits := [2];
    end;
    if aShape = 'ctl-rec-in-comp-method-free' then
    begin
      lExpectedTexts := [' lWithRecPtr := @R;' + #13#10 +
    ' lWithRecPtr^.B := Foo.Tag;'];
      lExpectedTemps := [1];
      lExpectedEdits := [2];
    end;
    if aShape = 'sr-name-ctl' then
    begin
      lExpectedTexts := [' S := SR.Name;'];
      lExpectedTemps := [0];
      lExpectedEdits := [1];
    end;
    if aShape = 'sr-fileio715' then
    begin
      lExpectedTexts := [' begin' + #13#10 +
    '  S := SR.Name;' + #13#10 +
    '  X := SR.Size + SR.Attr;' + #13#10 +
    ' end;'];
      lExpectedTemps := [0];
      lExpectedEdits := [1];
    end;
    if aShape = 'ctl-obj-absent-global' then
    begin
      lExpectedTexts := [' lWithBaz := Baz;' + #13#10 +
    ' lWithBaz.X := G;'];
      lExpectedTemps := [1];
      lExpectedEdits := [2];
    end;
    if aShape = 'obj-local-var-ctl' then
    begin
      lExpectedTexts := [' lWithBaz := Baz;' + #13#10 +
    ' lWithBaz.X := N;'];
      lExpectedTemps := [1];
      lExpectedEdits := [2];
    end;
    if aShape = 'ctl-comp-absent-global' then
    begin
      lExpectedTexts := [' lWithFoo := Foo;' + #13#10 +
    ' lWithFoo.X := G;'];
      lExpectedTemps := [1];
      lExpectedEdits := [2];
    end;
    if aShape = 'comp-local-var' then
    begin
      lExpectedTexts := [' lWithFoo := Foo;' + #13#10 +
    ' lWithFoo.X := N;'];
      lExpectedTemps := [1];
      lExpectedEdits := [2];
    end;
    if aShape = 'comp-same-name-field-ctl' then
    begin
      lExpectedTexts := [' lWithFoo := Foo;' + #13#10 +
    ' X := lWithFoo.Tag;'];
      lExpectedTemps := [1];
      lExpectedEdits := [2];
    end;
    if aShape = 'nested-outerrec-field-b' then
    begin
      lExpectedTexts := [' lWithRecPtr := @R;' + #13#10 +
    '   begin' + #13#10 +
    '    lWithFoo := Foo;' + #13#10 +
    '   lWithRecPtr^.B := 4;' + #13#10 +
    '  end;'];
      lExpectedTemps := [2];
      lExpectedEdits := [2];
    end;
    Assert.AreEqual(Length(lExpectedTexts), Length(lPlan.FinalStatements), aShape);
    for lStatementIndex := 0 to High(lPlan.FinalStatements) do
    begin
      Assert.AreEqual('planned', lPlan.FinalStatements[lStatementIndex].Status, aShape);
      Assert.AreEqual('', lPlan.FinalStatements[lStatementIndex].SafetyReason, aShape);
      Assert.AreEqual(lExpectedTexts[lStatementIndex],
        lPlan.FinalStatements[lStatementIndex].ReplacementText, aShape);
      Assert.AreEqual<Integer>(lExpectedTemps[lStatementIndex], Length(lPlan.FinalStatements[lStatementIndex].Temps), aShape);
      Assert.AreEqual<Integer>(lExpectedEdits[lStatementIndex], Length(lPlan.FinalStatements[lStatementIndex].Edits), aShape);
    end;
    Exit;
  end;
  lExpectedReason := 'OWNER_INHERITED_MEMBERS_UNVERIFIED';
  if StartsText('sr-', aShape) or (aShape = 'alias-projclass-classname') then
    lExpectedReason := 'ALIAS_RECEIVER_MEMBERS_UNVERIFIED';
  Assert.IsTrue(Length(lPlan.FinalStatements) > 0, aShape);
  for var lStatement in lPlan.FinalStatements do
  begin
    Assert.AreEqual('skipped', lStatement.Status, aShape + ': ' + lStatement.Reason);
    Assert.AreEqual(lExpectedReason, lStatement.SafetyReason, aShape);
    Assert.AreEqual('', lStatement.ReplacementText, aShape);
    Assert.AreEqual(0, Integer(Length(lStatement.Edits)), aShape);
    Assert.AreEqual(0, Integer(Length(lStatement.Temps)), aShape);
    for var lEdit in lPlan.Edits do
      Assert.AreNotEqual(lStatement.SemanticId, lEdit.StatementId, aShape);
  end;
end;

procedure TWithBinderTests.SimpleSelectorFallthroughRequiresExactRootAbsence(
  const aMode, aName, aExpectedStatus: string);
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lGuid: TGUID;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lProvider: IDelphiSemanticImplicitRootMemberAbsence;
  lRoot: string;
  lText: string;
begin
  CreateGUID(lGuid);
  lRoot := CombinePath([RepoRoot, 'tests', '.dak', 'delphiSemanticsTests',
    'ds712-simple-' + GUIDToString(lGuid)]);
  TDirectory.CreateDirectory(lRoot);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := TPath.Combine(lRoot, 'SimpleSelectors.pas');
  lText := 'unit SimpleSelectors;' + #13#10 +
    'interface' + #13#10 +
    'type' + #13#10 +
    '  TLeft = class' + #13#10 +
    '  public' + #13#10 +
    '    LeftOnly: Integer;' + #13#10 +
    '  end;' + #13#10 +
    '  TRight = record' + #13#10 +
    '    RightOnly: Integer;' + #13#10 +
    '  end;' + #13#10 +
    '  TOwner = class' + #13#10 +
    '  public' + #13#10 +
    '    class procedure Run;' + #13#10 +
    '  end;' + #13#10 +
    'implementation' + #13#10 +
    'class procedure TOwner.Run;' + #13#10 +
    'var' + #13#10 +
    '  lLeft: TLeft;' + #13#10 +
    '  ' + aName + ': TRight;' + #13#10 +
    'begin' + #13#10 +
    '  with lLeft, ' + aName + ' do RightOnly := 1;' + #13#10 +
    'end;' + #13#10 +
    'end.' + #13#10;
  TFile.WriteAllText(lOptions.SourceFileName, lText, TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  TFile.WriteAllText(TPath.Combine(lRoot, 'model.json'), ModelToJson(lModel), TEncoding.UTF8);
  Assert.IsTrue(lModel.Success, 'The selector control requires a real complete source model.');
  Assert.AreEqual(0, lModel.RejectedDeclarationCount, 'The positive control must have no rejected declarations.');
  if aMode <> 'missing' then
    lProvider := TImplicitRootAbsenceStub.Create;
  lFacts := TDelphiSemanticWithBinder.BindProject('simple-selector-root-' + aMode,
    nil, [lModel], lProvider);
  Assert.AreEqual(1, Integer(Length(lFacts.Bindings)));
  Assert.AreEqual(2, Integer(Length(lFacts.Bindings[0].Selectors)));
  Assert.AreEqual(aExpectedStatus, lFacts.Bindings[0].Selectors[1].Status);
  if aExpectedStatus = 'resolved' then
    Assert.AreEqual('TRight', lFacts.Bindings[0].Selectors[1].TypeName);
end;

procedure TWithBinderTests.RootAbsenceRequiresClosedImportedSource(
  const aBarrier, aExpectedStatus: string);
var
  i: Integer;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lDiagnostic: TDelphiSemanticModelDiagnostic;
  lGuid: TGUID;
  lHelperDiagnosticCount: Integer;
  lModel: TDelphiSemanticUnitModel;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lOptions: TDelphiSemanticModelOptions;
  lProvider: IDelphiSemanticImplicitRootMemberAbsence;
  lRoot: string;
  lSupport: TDelphiSemanticUnitModel;
  lText: string;
begin
  CreateGUID(lGuid);
  lRoot := CombinePath([RepoRoot, 'tests', '.dak', 'delphiSemanticsTests',
    'ds715-closure-' + GUIDToString(lGuid)]);
  TDirectory.CreateDirectory(lRoot);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := TPath.Combine(lRoot, 'MultipleSelectorUnit.pas');
  lText := TFile.ReadAllText(TPath.GetFullPath(TPath.Combine(RepoRoot,
    '..\DelphiAiKit\tests\fixtures\RemoveWithMultipleSelectorRewriteFixture\MultipleSelectorUnit.pas')));
  lText := StringReplace(lText, 'interface', 'interface' + #13#10 + 'uses ClosureSupport;', []);
  TFile.WriteAllText(lOptions.SourceFileName, lText, TEncoding.UTF8);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(0, lModel.RejectedDeclarationCount);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'ClosureSupport.pas');
  lText := 'unit ClosureSupport;' + #13#10 + 'interface' + #13#10 +
    'type' + #13#10 + '  TMarker = record' + #13#10 + '    Number: Integer;' + #13#10 +
    '  end;' + #13#10;
  if StartsText('helper', aBarrier) then
    lText := lText + '  TObjectExtraHelper = class helper for TObject' + #13#10 +
      '    procedure Extra;' + #13#10 + '  end;' + #13#10;
  if StartsText('record-helper', aBarrier) then
  begin
    if aBarrier = 'record-helper-alias' then
      lText := lText + '  TAlias = TMarker;' + #13#10;
    if aBarrier = 'record-helper-local' then
      lText := lText + '  TMarkerHelper = record helper for LocalMarker' + #13#10
    else if aBarrier = 'record-helper-alias' then
      lText := lText + '  TMarkerHelper = record helper for TAlias' + #13#10
    else
      lText := lText + '  TMarkerHelper = record helper for TMarker' + #13#10;
    lText := lText + '    procedure Extra;' + #13#10 + '  end;' + #13#10;
  end;
  if StartsText('routine-', aBarrier) then
    lText := lText + 'procedure SupportRoutine;' + #13#10;
  lText := lText + 'implementation' + #13#10;
  if StartsText('helper', aBarrier) then
    lText := lText + 'procedure TObjectExtraHelper.Extra; begin end;' + #13#10;
  if StartsText('record-helper', aBarrier) then
    lText := lText + 'procedure TMarkerHelper.Extra; begin end;' + #13#10;
  if StartsText('routine-', aBarrier) then
    lText := lText + 'procedure SupportRoutine; begin end;' + #13#10;
  if aBarrier = 'record-helper-local' then
    lText := lText + 'procedure LocalScope;' + #13#10 +
      'type LocalMarker = record Value: Integer; end;' + #13#10 +
      'begin end;' + #13#10;
  lText := lText + 'end.' + #13#10;
  if aBarrier = 'helper-escaped-name' then
    lText := StringReplace(lText, 'TObjectExtraHelper', '&type', [rfReplaceAll]);
  if aBarrier = 'helper-unindexed-empty' then
    lText := 'unit ClosureSupport; interface type &type = class helper for TObject end; implementation end.';
  TFile.WriteAllText(lOptions.SourceFileName, lText, TEncoding.ASCII);
  lSupport := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lSupport.Success);
  if MatchText(aBarrier, ['helper-escaped-name', 'helper-unindexed-empty']) then
  begin
    TFile.WriteAllText(TPath.Combine(lRoot, 'support-model.json'),
      ModelToJson(lSupport), TEncoding.UTF8);
    Assert.AreEqual('ast', lSupport.ScopeModelStatus);
    if aBarrier = 'helper-escaped-name' then
      // Our line scanner also rejects Extra under the escaped helper owner.
      Assert.AreEqual(2, lSupport.RejectedDeclarationCount)
    else
      Assert.AreEqual(1, lSupport.RejectedDeclarationCount);
    lHelperDiagnosticCount := 0;
    for lDiagnostic in lSupport.Diagnostics do
      if lDiagnostic.Code = 'AST_HELPER_DECLARATION_UNINDEXED' then
      begin
        Inc(lHelperDiagnosticCount);
        Assert.IsTrue(ContainsText(lDiagnostic.Message, 'column'));
      end;
    Assert.AreEqual(1, lHelperDiagnosticCount);
  end;
  if aBarrier = 'record-helper' then
    Assert.AreEqual(0, lSupport.RejectedDeclarationCount);
  for i := 0 to High(lSupport.Declarations) do
  begin
    if SameText(lSupport.Declarations[i].Name, 'TObjectExtraHelper') then
    begin
      if aBarrier = 'helper-unverified' then
        lSupport.Declarations[i].AstHelperKind := '';
      if MatchText(aBarrier, ['helper-unverified', 'helper-empty-target']) then
        lSupport.Declarations[i].HelperTargetName := '';
    end;
    if (aBarrier = 'record-helper-missing') and
      SameText(lSupport.Declarations[i].Name, 'TMarkerHelper') then
      lSupport.Declarations[i].HelperTargetName := 'MissingRecord';
  end;
  if aBarrier = 'failed' then
    lSupport.Success := False
  else if aBarrier = 'interface-only' then
    lSupport.ScopeModelStatus := 'ast-interface-only'
  else if aBarrier = 'rejected' then
    lSupport.RejectedDeclarationCount := 1;
  if StartsText('routine-', aBarrier) then
  begin
    Assert.IsTrue(lSupport.RejectedDeclarationCount > 0);
    Assert.IsTrue(Length(lSupport.Routines) > 0);
    Assert.IsTrue(lSupport.Routines[0].AstSourceSignatureVerified);
    if aBarrier = 'routine-unverified' then
      lSupport.Routines[0].AstSourceSignatureVerified := False
    else if aBarrier = 'routine-position' then
      Inc(lSupport.Routines[0].Line)
    else if aBarrier = 'routine-parent' then
      lSupport.Routines[0].ParentScopeId := 'unverified-parent';
    for i := 0 to High(lSupport.Declarations) do
      if SameText(lSupport.Declarations[i].Kind, 'routine') and
        SameText(lSupport.Declarations[i].DeclarationRole, 'invalid') then
      begin
        if aBarrier = 'routine-declaration-file' then
          lSupport.Declarations[i].FileName := TPath.Combine(lRoot, 'DifferentInclude.inc')
        else if aBarrier = 'routine-declaration-scope' then
          lSupport.Declarations[i].ScopeKind := 'routine'
        else if aBarrier = 'routine-declaration-owner' then
          lSupport.Declarations[i].OwnerName := 'DifferentOwner'
        else if aBarrier = 'routine-declaration-owner-scope' then
          lSupport.Declarations[i].OwnerScopeId := 'different-owner-scope';
      end;
  end;
  lModels := [lModel, lSupport];
  if aBarrier = 'missing' then
    lModels := [lModel]
  else if aBarrier = 'ambiguous' then
    lModels := [lModel, lSupport, lSupport];
  lProvider := TImplicitRootAbsenceStub.Create;
  lFacts := TDelphiSemanticWithBinder.BindProject('closed-source-root-' + aBarrier,
    nil, lModels, lProvider);
  Assert.AreEqual(2, Integer(Length(lFacts.Bindings)));
  Assert.AreEqual(2, Integer(Length(lFacts.Bindings[0].Selectors)));
  Assert.AreEqual(aExpectedStatus, lFacts.Bindings[0].Selectors[1].Status);
  // Keep the source-backed field declaration proof independent of the import result.
  for i := 0 to High(lModel.Members) do
    if SameText(lModel.Members[i].Name, 'fLeft') then
      Assert.AreEqual('field', lModel.Members[i].Kind);
end;

procedure TWithBinderTests.FieldSelectorsRetainTheirDeclaredKinds;
var
  lBinding: TDelphiSemanticWithBinding;
  lDiagnostics: string;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lFieldCount: Integer;
  lGuid: TGUID;
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lRoot: string;
  lRootMemberAbsence: IDelphiSemanticImplicitRootMemberAbsence;
  lSelector: TDelphiSemanticWithSelectorBinding;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := TPath.GetFullPath(TPath.Combine(RepoRoot,
    '..\DelphiAiKit\tests\fixtures\RemoveWithMultipleSelectorRewriteFixture\MultipleSelectorUnit.pas'));
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  CreateGUID(lGuid);
  lRoot := TPath.Combine(RepoRoot, 'tests\.dak\delphiSemanticsTests\ds712-field-' +
    GUIDToString(lGuid));
  TDirectory.CreateDirectory(lRoot);
  TFile.WriteAllText(TPath.Combine(lRoot, 'model.json'), ModelToJson(lModel), TEncoding.UTF8);
  lRootMemberAbsence := TImplicitRootAbsenceStub.Create;
  lFacts := TDelphiSemanticWithBinder.BindProject('field-selector-regression', nil, [lModel],
    lRootMemberAbsence);
  lDiagnostics := '';
  for lBinding in lFacts.Bindings do
    for lSelector in lBinding.Selectors do
      lDiagnostics := lDiagnostics + lBinding.RoutineName + ': ' + lSelector.SelectorText +
        ': ' + lSelector.Status + ':' + lSelector.TypeName + ':' + lSelector.ReasonCode + #13#10;
  TFile.WriteAllText(TPath.Combine(lRoot, 'selectors.txt'), lDiagnostics, TEncoding.UTF8);
  lFieldCount := 0;
  for lMember in lModel.Members do
    if SameText(lMember.OwnerName, 'TMultiPair') and
      (SameText(lMember.Name, 'fLeft') or SameText(lMember.Name, 'fRight')) then
    begin
      Inc(lFieldCount);
      Assert.AreEqual('field', lMember.Kind, lMember.Name);
      Assert.AreNotEqual('', lMember.TypeName, lMember.Name);
    end;
  Assert.AreEqual(2, lFieldCount);
  Assert.AreEqual(2, Integer(Length(lFacts.Bindings)));
  Assert.AreEqual(2, Integer(Length(lFacts.Bindings[0].Selectors)));
  Assert.AreEqual('lPair.fLeft', lFacts.Bindings[0].Selectors[0].SelectorText);
  Assert.AreEqual('resolved', lFacts.Bindings[0].Selectors[0].Status, lDiagnostics);
  Assert.AreEqual('TMultiLeft', lFacts.Bindings[0].Selectors[0].TypeName);
  Assert.AreEqual('lPair.fRight', lFacts.Bindings[0].Selectors[1].SelectorText);
  Assert.AreEqual('resolved', lFacts.Bindings[0].Selectors[1].Status, lDiagnostics);
  Assert.AreEqual('TMultiRight', lFacts.Bindings[0].Selectors[1].TypeName);
  Assert.IsTrue(HasReference(lFacts.Bindings[0], 'Code1', 'member'), lDiagnostics);
  Assert.IsTrue(HasReference(lFacts.Bindings[0], 'RightOnly', 'member'), lDiagnostics);
  Assert.IsTrue(HasReference(lFacts.Bindings[0], 'LeftOnly', 'member'));
  Assert.AreEqual('TMultiLeft', ReceiverOf(lFacts.Bindings[0], 'LeftOnly', 'member'));
end;

procedure TWithBinderTests.OptionalRootAbsenceKeepsUnverifiedContextsBlocked(const aBarrier: string);
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lProvider: IDelphiSemanticImplicitRootMemberAbsence;
  lText: string;
begin
  lText := TFile.ReadAllText(TPath.GetFullPath(TPath.Combine(RepoRoot,
    '..\DelphiAiKit\tests\fixtures\RemoveWithMultipleSelectorRewriteFixture\MultipleSelectorUnit.pas')),
    TEncoding.UTF8);
  if aBarrier = 'import' then
    lText := StringReplace(lText, 'interface', 'interface' + #13#10 + 'uses System;', [])
  else if aBarrier = 'helper' then
    lText := StringReplace(lText, 'implementation',
      'type TExtraHelper = class helper for TMultiLeft' + #13#10 +
      'procedure Extra;' + #13#10 + 'end;' + #13#10 +
      'implementation' + #13#10 + 'procedure TExtraHelper.Extra; begin end;', [])
  else if aBarrier = 'ancestor' then
    lText := StringReplace(lText, 'TMultiLeft = class', 'TMultiLeft = class(TUnindexed)', [])
  else if aBarrier = 'system' then
    lText := StringReplace(lText, 'unit MultipleSelectorUnit;', 'unit System;', []);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := WithBinderTempPath('RootAbsence-' + aBarrier + '.pas');
  TFile.WriteAllText(lOptions.SourceFileName, lText, TEncoding.UTF8);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success, 'The control must start with a source-extracted model.');
  if aBarrier = 'failed' then
    lModel.Success := False
  else if aBarrier = 'interface-only' then
    lModel.ScopeModelStatus := 'ast-interface-only'
  else if aBarrier = 'rejected' then
    lModel.RejectedDeclarationCount := 1;
  if aBarrier <> 'missing' then
    lProvider := TImplicitRootAbsenceStub.Create;
  lFacts := TDelphiSemanticWithBinder.BindProject('root-absence-guard-' + aBarrier,
    nil, [lModel], lProvider);
  Assert.AreEqual(2, Integer(Length(lFacts.Bindings)));
  Assert.AreEqual(2, Integer(Length(lFacts.Bindings[0].Selectors)));
  Assert.AreEqual('unsupported', lFacts.Bindings[0].Selectors[1].Status);
  Assert.AreEqual('OWNER_INHERITED_MEMBERS_UNVERIFIED',
    lFacts.Bindings[0].Selectors[1].ReasonCode);
end;


procedure TWithBinderTests.OperatorIdentifierDoesNotHideDeclarations(const aShape: string);
var
  lRoot, lBody, lLocal: string;
  lOptions: TDelphiSemanticApiOptions;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lBinding: TDelphiSemanticWithBinding;
  lReference: TDelphiSemanticBoundReference;
  lFound: Boolean;
begin
  lRoot := WithBinderTempPath('OperatorIdentifier-' + aShape);
  TDirectory.CreateDirectory(lRoot);
  lBody := 'Value: Integer;';
  lLocal := 'var'#13#10'  Operator: Char;'#13#10'  Count: Integer;'#13#10;
  if aShape = 'field' then
  begin
    lBody := 'Operator: Char;'#13#10'    Count: Integer;';
    lLocal := '';
  end;
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'), 'program P; uses Unit1; begin end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dproj'),
    '<Project><PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="Unit1.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
    'unit Unit1;'#13#10'interface'#13#10'type'#13#10'  TR = record'#13#10 +
    '    ' + lBody + #13#10'  end;'#13#10 + lLocal + 'implementation'#13#10 +
    'procedure Run(var R: TR);'#13#10'begin'#13#10 +
    '  with R do Count := Count + 1;'#13#10'end;'#13#10'end.', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.Combine(lRoot, 'P.dproj');
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  lFound := False;
  for lBinding in lFacts.Bindings do
    for lReference in lBinding.References do
      if SameText(lReference.Name, 'Count') then
      begin
        lFound := True;
        if aShape = 'local' then
          Assert.AreEqual('lexical', lReference.Classification, lReference.ReasonCode)
        else
          Assert.AreEqual('member', lReference.Classification, lReference.ReasonCode);
      end;
  Assert.IsTrue(lFound);
end;

procedure TWithBinderTests.VerifiedCrossUnitReceiverKeepsMember(const aShape: string);
var
  lOptions: TDelphiSemanticApiOptions;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lBinding: TDelphiSemanticWithBinding;
  lReference: TDelphiSemanticBoundReference;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
  lRoot, lType, lSelector, lVars, lControl, lExpectedClass, lExpectedReason: string;
  lFound: Boolean;
begin
  lRoot := WithBinderTempPath('VerifiedCrossUnit-' + aShape);
  TDirectory.CreateDirectory(lRoot);
  lType := 'TFoo = class(ControlUnit.TFoo) end;';
  lControl := 'TFoo = class Count: Integer; end;';
  if StartsText('alias', aShape) then
  begin
    lType := 'TFoo = ControlUnit.TFoo;';
    lControl := 'TFoo = record Count: Integer; end;';
  end;
  lExpectedClass := 'member';
  lExpectedReason := 'receiver-type-not-visible';
  if StartsText('alias', aShape) and (aShape <> 'alias-plain') then
  begin
    lExpectedClass := 'unsupported';
    lExpectedReason := 'selector-type-not-resolved';
  end;
  lVars := 'var Arr: array[0..0] of TFoo;';
  lSelector := 'Arr[0]';
  if EndsText('pointer', aShape) then
  begin
    lVars := 'var Ptr: ^TFoo;';
    lSelector := 'Ptr^';
  end;
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P; uses Unit1, ControlUnit; begin end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'ControlUnit.pas'),
    'unit ControlUnit;'#13#10'interface'#13#10'type ' + lControl +
    #13#10'implementation'#13#10'end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
    'unit Unit1;'#13#10'interface'#13#10'uses ControlUnit;'#13#10'type ' + lType +
    #13#10 + lVars + #13#10'implementation'#13#10'procedure Run;'#13#10'begin'#13#10 +
    '  with ' + lSelector + ' do Count := Count + 1;'#13#10'end;'#13#10'end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dproj'),
    '<Project><PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="Unit1.pas"/><DCCReference Include="ControlUnit.pas"/>' +
    '</ItemGroup></Project>', TEncoding.ASCII);
  if MatchText(aShape, ['alias-plain', 'alias-ptr']) then
  begin
    lType := '';
    lVars := 'var R: TRec;';
    lSelector := 'R';
    if aShape = 'alias-ptr' then
    begin
      lType := '  PRec = ^TRec;'#13#10;
      lVars := 'var P: PRec;';
      lSelector := 'P^';
    end;
    TFile.WriteAllText(TPath.Combine(lRoot, 'ControlUnit.pas'),
      'unit ControlUnit;'#13#10'interface'#13#10 +
      'type TRec = record Count: Integer; end;'#13#10'implementation'#13#10#13#10'end.',
      TEncoding.ASCII);
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
      'unit Unit1;'#13#10'interface'#13#10'uses ControlUnit;'#13#10 +
      'type TRec = ControlUnit.TRec;'#13#10 + lType + lVars +
      #13#10'implementation'#13#10'procedure Run;'#13#10'begin'#13#10 +
      '  with ' + lSelector + ' do Count := Count + 1;'#13#10'end;'#13#10'end.', TEncoding.ASCII);
  end;
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.Combine(lRoot, 'P.dpr');
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  lFound := False;
  for lBinding in lFacts.Bindings do
    if SameText(lBinding.UnitName, 'Unit1') then
      for lReference in lBinding.References do
        if SameText(lReference.Name, 'Count') then
        begin
          lFound := True;
          Assert.AreEqual(lExpectedClass, lReference.Classification, aShape + ': ' + lReference.ReasonCode);
        end;
  Assert.IsTrue(lFound);
  lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
  lFound := False;
  for lStatement in lPlan.FinalStatements do
    if SameText(ExtractFileName(lStatement.FileName), 'Unit1.pas') then
    begin
      lFound := True;
      // Native base already refuses this homonymous receiver at final DTO publication.
      Assert.AreEqual('skipped', lStatement.Status);
      Assert.AreEqual(lExpectedReason, lStatement.Reason);
      Assert.AreEqual(lExpectedReason, lStatement.SafetyReason);
      Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
      Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
      Assert.AreEqual('', lStatement.ReplacementText);
    end;
  Assert.IsTrue(lFound);
end;

procedure TWithBinderTests.ReceiverOwnerIdentityAndMemberActivity(const aShape: string);
var
  lOptions: TDelphiSemanticApiOptions;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
  lEdit: TDelphiSemanticRemoveWithEdit;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lBinding: TDelphiSemanticWithBinding;
  lReference: TDelphiSemanticBoundReference;
  lRoot, lField, lExtra, lLocal, lBody, lControlType, lExpectedReason, lImports, lReceiverType: string;
  lPass: Integer;
  lFound, lFoundControl, lFoundReference, lCandidate: Boolean;
begin
  lRoot := WithBinderTempPath('ReceiverOwnerActivity-' + aShape);
  TDirectory.CreateDirectory(lRoot);
  lField := 'Other: Integer;';
  lExtra := '';
  lLocal := '';
  lBody := 'with Rec do Count := Count + 1;';
  lControlType := 'TRec';
  lImports := '';
  lReceiverType := 'TRec';
  if aShape = 'context-borrow' then
  begin
    lImports := 'uses ControlUnit;'#13#10;
  end;
  lExpectedReason := 'receiver-member-owner-conflict';
  if aShape = 'context-borrow' then
    lExpectedReason := 'receiver-type-not-visible';
  if aShape = 'selected-unknown' then
  begin
    lField := '{$IFNDEF LINUX} Count: Integer; {$ENDIF}';
    lExpectedReason := 'members-unverified';
  end else if aShape = 'selector-selected' then
  begin
    lExtra := 'type TOuter = record {$IFNDEF LINUX} Child: TRec; {$ENDIF} end;'#13#10 +
      'var Outer: TOuter;'#13#10;
    lBody := 'with Outer.Child do Count := Count + 1;';
    lExpectedReason := 'property-selector';
  end else if aShape = 'homonym-lexical' then
    lExtra := 'var Count: Integer;'#13#10
  else if aShape = 'homonym-constant' then
  begin
    lExtra := 'const Count = 10;'#13#10;
    lBody := 'with Rec do Other := Count;';
  end else if aShape = 'local-type' then
  begin
    lLocal := 'type TLocal = record {$IFDEF LINUX} Count: Integer; {$ENDIF} end;'#13#10 +
      'var LocalRec: TLocal;'#13#10;
    lBody := 'with LocalRec do Count := Count + 1;';
    lExpectedReason := 'receiver-member-not-found';
  end else if aShape = 'lexical-unknown-no-homonym' then
  begin
    lExtra := '{$IFNDEF LINUX} var Count: Integer; {$ENDIF}'#13#10;
    lControlType := 'TControlRec';
    lExpectedReason := '';
  end else if aShape = 'known-inactive-member' then
  begin
    lField := '{$IFDEF NEVER_DEFINED} Count: Integer; {$ENDIF}';
    lControlType := 'TControlRec';
    lExpectedReason := 'receiver-member-not-found';
  end;
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P; uses Unit1, ControlUnit; begin end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dproj'),
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="Unit1.pas"/>' +
    '<DCCReference Include="ControlUnit.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
    'unit Unit1;'#13#10'interface'#13#10 +
    'type TRec = record ' + lField + ' end;'#13#10'var Rec: ' + lReceiverType + ';'#13#10 +
    lExtra + 'implementation'#13#10 + lImports + 'procedure Run;'#13#10 +
    lLocal + 'begin'#13#10 + lBody + #13#10'end;'#13#10'end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'ControlUnit.pas'),
    'unit ControlUnit;'#13#10'interface'#13#10 +
    'type ' + lControlType + ' = record Count: Integer; end;'#13#10 +
    'var ControlRec: ' + lControlType + ';'#13#10 +
    'implementation'#13#10'procedure Run; begin with ControlRec do Count := Count + 1; end;'#13#10 +
    'end.', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.Combine(lRoot, 'P.dproj');
  if aShape = 'known-inactive-member' then
  begin
    lOptions.Configuration := 'Debug';
    lOptions.Platform := 'Win64';
    lOptions.DelphiVersion := '23.0';
  end;
  lOptions.Cache.SqliteCacheFileName := TPath.Combine(lRoot, 'owner-activity.sqlite');
  if TFile.Exists(lOptions.Cache.SqliteCacheFileName) then
    TFile.Delete(lOptions.Cache.SqliteCacheFileName);
  for lPass := 0 to 1 do
  begin
    lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
    lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
    lFound := False;
    lFoundControl := False;
    for lStatement in lPlan.FinalStatements do
      if SameText(ExtractFileName(lStatement.FileName), 'Unit1.pas') then
      begin
        lFound := True;
        if lExpectedReason = '' then
        begin
          Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
          Assert.IsTrue(ContainsText(lStatement.ReplacementText, 'Count := Count + 1'));
          Assert.IsFalse(ContainsText(lStatement.ReplacementText, '.Count'));
        end else begin
          Assert.AreEqual('skipped', lStatement.Status, aShape);
          Assert.AreEqual(lExpectedReason, lStatement.Reason);
          Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
          Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
          Assert.AreEqual('', lStatement.ReplacementText);
          lCandidate := False;
          for lEdit in lPlan.Edits do
            if lEdit.StatementId = lStatement.SemanticId then
              lCandidate := True;
          Assert.AreEqual(MatchText(aShape, ['known-inactive-member', 'context-borrow']), lCandidate,
            'Only the ordinary known-inactive refusal keeps candidate coverage.');
        end;
      end else if SameText(ExtractFileName(lStatement.FileName), 'ControlUnit.pas') then
      begin
        lFoundControl := True;
        Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
      end;
    Assert.IsTrue(lFound);
    Assert.IsTrue(lFoundControl);
    if MatchText(aShape, ['selector-selected', 'local-type']) then
      for lBinding in lFacts.Bindings do
        if SameText(lBinding.UnitName, 'Unit1') then
        begin
          Assert.AreEqual('MEMBERS_UNVERIFIED', lBinding.SkipReason);
        end;
    if MatchText(aShape, ['context-borrow', 'homonym-lexical', 'homonym-constant']) then
    begin
      lFoundReference := False;
      for lBinding in lFacts.Bindings do
        if SameText(lBinding.UnitName, 'Unit1') then
          for lReference in lBinding.References do
            if SameText(lReference.Name, 'Count') then
            begin
              lFoundReference := True;
              Assert.AreNotEqual('member', lReference.Classification);
              if MatchText(aShape, ['homonym-lexical', 'homonym-constant']) then
                Assert.AreEqual('lexical', lReference.Classification);
            end;
      Assert.IsTrue(lFoundReference);
    end;
  end;
end;

procedure TWithBinderTests.UnknownActivityCannotAuthorizeRemoveWith(const aShape: string);
var
  lOptions: TDelphiSemanticApiOptions;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
  lEdit: TDelphiSemanticRemoveWithEdit;
  lRoot, lPrefix, lField, lBody, lExtra, lLocal: string;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lBinding: TDelphiSemanticWithBinding;
  lReference: TDelphiSemanticBoundReference;
  lPass, lAffectedCount: Integer;
  lActive: Boolean;
  lFoundSkipped, lFoundControl: Boolean;
begin
  lRoot := WithBinderTempPath('UnknownWith-' + aShape);
  TDirectory.CreateDirectory(lRoot);
  lPrefix := '';
  if aShape = 'missing' then
    lPrefix := '{$IFDEF LINUX}{$I Missing.inc}{$ENDIF}'#13#10
  else if aShape = 'directive' then
    lPrefix := '{$HINTS OFF}'#13#10;
  lExtra := '';
  lLocal := '';
  lActive := aShape = 'active';
  lField := 'Count: Integer;';
  lBody := '{$IFNDEF LINUX} with Rec do Count := Count + 1; {$ENDIF}';
  if aShape = 'declared-receiver' then
  begin
    lField := '{$IF Declared(TRec)} Count: Integer; {$IFEND}';
    lBody := 'with Rec do Count := Count + 1;';
  end;
  if aShape = 'declaration' then
  begin
    lField := '{$IFDEF LINUX} Count: Integer; {$ENDIF}';
    lBody := 'with Rec do Count := Count + 1;';
  end;
  if MatchText(aShape, ['selected-field', 'active', 'inactive']) then
  begin
    lField := '{$IFDEF MSWINDOWS} Count: Integer; {$ENDIF}';
    if aShape = 'inactive' then
      lField := '{$IFDEF LINUX} Count: Integer; {$ENDIF}';
    lBody := 'with Rec do Count := Count + 1;';
  end else if MatchText(aShape, ['global', 'local']) then
  begin
    lField := 'Other: Integer;';
    if aShape = 'global' then
      lExtra := '{$IFDEF MSWINDOWS} var Count: Integer; {$ENDIF}'#13#10
    else
      lLocal := '{$IFDEF MSWINDOWS} var Count: Integer; {$ENDIF}'#13#10;
    lBody := 'with Rec do Count := Count + 1;';
  end else if aShape = 'selector' then
  begin
    lExtra := 'type TOuter = record {$IFDEF MSWINDOWS} Child: TRec; {$ENDIF} end;'#13#10 +
      'var Outer: TOuter;'#13#10;
    lBody := 'with Outer.Child do Count := Count + 1;';
  end else if aShape = 'activity-nested' then
  begin
    lBody := 'with Rec do begin {$IFNDEF LINUX} with Rec do Count := Count + 1; {$ENDIF} end;';
  end else if aShape = 'nested' then
  begin
    lField := '{$IFDEF LINUX} Count: Integer; {$ENDIF}';
    lBody := 'with Rec do begin with Rec do Count := Count + 1; end;';
  end;
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P; uses Unit1, ControlUnit; begin end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dproj'),
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="Unit1.pas"/>' +
    '<DCCReference Include="ControlUnit.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
    'unit Unit1;'#13#10'interface'#13#10 +
    'type TRec = record ' + lField + ' end;'#13#10'var Rec: TRec;'#13#10 +
    lExtra + 'implementation'#13#10 + lPrefix + 'procedure Run;'#13#10 + lLocal + 'begin'#13#10 +
    lBody + #13#10'end;'#13#10'end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'ControlUnit.pas'),
    'unit ControlUnit;'#13#10'interface'#13#10 +
    'type TRec = record Count: Integer; end;'#13#10'var Rec: TRec;'#13#10 +
    'implementation'#13#10'procedure Run; begin with Rec do Count := Count + 1; end;'#13#10 +
    'end.', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.Combine(lRoot, 'P.dproj');
  if aShape = 'ancestor-declaration' then
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
      'unit Unit1;'#13#10'interface'#13#10 +
      'type TBase = class {$IF Declared(TBase)} Count: Integer; {$IFEND} end;'#13#10 +
      'TRec = class(TBase) end;'#13#10'var Rec: TRec;'#13#10 +
      'implementation'#13#10'procedure Run;'#13#10'begin'#13#10 +
      'with Rec do begin Count := 1;'#13#10'end;'#13#10'end;'#13#10'end.', TEncoding.ASCII);
  if MatchText(aShape, ['active', 'inactive', 'ancestor-declaration']) then
  begin
    lOptions.Configuration := 'Debug';
    lOptions.Platform := 'Win64';
    lOptions.DelphiVersion := '23.0';
  end;
  lOptions.Cache.SqliteCacheFileName := TPath.Combine(lRoot, 'round11-cache.sqlite');
  if TFile.Exists(lOptions.Cache.SqliteCacheFileName) then
    TFile.Delete(lOptions.Cache.SqliteCacheFileName);
  for lPass := 0 to 1 do
  begin
    lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lOptions);
    if aShape = 'ancestor-declaration' then
      Assert.AreEqual('blocked', lPlan.Status, lPlan.Diagnostic)
    else
      Assert.AreEqual('planned', lPlan.Status, lPlan.Diagnostic);
    Assert.IsNotEmpty(lPlan.ContextFingerprint, 'Control statement retains its apply context.');
    lAffectedCount := 0;
    lFoundSkipped := False;
    lFoundControl := False;
    for lStatement in lPlan.FinalStatements do
      if SameText(ExtractFileName(lStatement.FileName), 'Unit1.pas') then
      begin
        Inc(lAffectedCount);
        if lActive then
        begin
          Assert.AreEqual('planned', lStatement.Status);
          Assert.IsTrue(Length(lStatement.Edits) > 0);
        end else begin
          Assert.AreEqual('skipped', lStatement.Status, 'Unknown declaration/activity cannot authorize apply.');
          if MatchText(aShape, ['mixed', 'missing', 'activity-nested']) then
            Assert.AreEqual('activity-unverified', lStatement.Reason)
          else if aShape = 'directive' then
            Assert.AreEqual('receiver-type-not-visible', lStatement.Reason)
          else if aShape = 'ancestor-declaration' then
            Assert.AreEqual('members-unverified', lStatement.Reason);
          Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
          Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
          Assert.AreEqual('', lStatement.ReplacementText);
        end;
        lFoundSkipped := True;
      end else if SameText(ExtractFileName(lStatement.FileName), 'ControlUnit.pas') then
      begin
        if aShape = 'ancestor-declaration' then
        begin
          // Native base contract: ds-721/ancestor-exact-native-base.log.
          Assert.AreEqual('skipped', lStatement.Status);
          Assert.AreEqual('receiver-type-not-visible', lStatement.Reason);
          Assert.AreEqual('receiver-type-not-visible', lStatement.SafetyReason);
          Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
          Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
          Assert.AreEqual('', lStatement.ReplacementText);
          for lEdit in lPlan.Edits do
            if lEdit.StatementId = lStatement.SemanticId then
              lFoundControl := True;
          Assert.IsTrue(lFoundControl, 'The established refusal retains its candidate.');
        end else begin
          Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
          Assert.IsTrue(Length(lStatement.Edits) > 0);
          lFoundControl := True;
        end;
      end;
    Assert.IsTrue(lFoundSkipped, 'Expected affected statement DTO.');
    Assert.IsTrue(lFoundControl, 'Expected unrelated known-active statement DTO.');
    if MatchText(aShape, ['nested', 'activity-nested']) then
      Assert.AreEqual(2, lAffectedCount, 'Inner unsafe statement must retain its parent.');
    if not lActive then
      for lEdit in lPlan.Edits do
        Assert.IsFalse(SameText(ExtractFileName(lEdit.FileName), 'Unit1.pas'),
          'Retained fingerprint cannot authorize any candidate edit in the skipped unit.');
    if aShape = 'inactive' then
    begin
      lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
      for lBinding in lFacts.Bindings do
        if SameText(lBinding.UnitName, 'Unit1') then
          for lReference in lBinding.References do
            Assert.AreNotEqual('member', lReference.Classification,
              'Known-false field must not borrow a foreign member.');
    end;
  end;
end;

procedure TWithBinderTests.WholeWithSourceActivityIsRequired(const aShape: string);
var
  lOptions: TDelphiSemanticApiOptions;
  lPlan, lSnapshotPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
  lExpectedReason: string;
  lRoot, lField, lBody: string;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lPass, lAffectedCount: Integer;
  lFoundSkipped, lFoundControl: Boolean;
begin
  lRoot := WithBinderTempPath('UnknownWith-' + aShape);
  TDirectory.CreateDirectory(lRoot);
  lField := 'Count: Integer;';
  lExpectedReason := 'activity-unverified';
  lBody := 'with Rec do begin Count := 1;'#13#10;
  if aShape = 'hidden-if' then
    lBody := lBody + '{$IF UseFast}{$ELSE} with Rec do Count := 5; {$IFEND}'
  else if aShape = 'hidden-declared' then
    lBody := lBody + '{$IF Declared(TFoo)} with Rec do Count := 5; {$IFEND}'
  else if aShape = 'hidden-malformed' then
    lBody := lBody + '{$IFDEF MSWINDOWS trailing} with Rec do Count := 5; {$ENDIF}'
  else if aShape = 'hidden-linux' then
    lBody := lBody + '{$IFDEF LINUX} with Rec do Count := 5; {$ENDIF}'
  else if aShape = 'hidden-missing' then
    lBody := lBody + '{$IFNDEF LINUX}{$I Missing.inc}{$ENDIF}'
  else if aShape = 'hidden-include' then
    lBody := lBody + '{$IFDEF LINUX}{$I Body.inc}{$ENDIF}'
  else if aShape = 'selector-text' then
    lBody := 'with {$IFDEF LINUX} Rec {$ELSE} Rec {$ENDIF} do begin Count := Count + 1;'
  else if aShape = 'taint' then
    lBody := lBody + '{$UNDEF X}{$IFDEF LINUX}{$I Missing.inc}{$ENDIF}' +
      '{$IFDEF X} Count := 2; {$ENDIF}'
  else if aShape = 'ancestor-control' then
  begin
    lField := '';
  end else if aShape = 'binder-unresolved' then
  begin
    lBody := 'with Rec do begin Missing := 1; {$IFNDEF LINUX} Count := 2; {$ENDIF}';
    lExpectedReason := 'receiver-member-not-found';
  end else if aShape = 'binder-scoped' then
  begin
    lBody := 'with Rec do begin var Local := 1; {$IFNDEF LINUX} Count := 2; {$ENDIF}';
    lExpectedReason := 'activity-unverified';
  end;
  lBody := lBody + #13#10'end;';
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P; uses Unit1, ControlUnit; begin end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dproj'),
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="Unit1.pas"/>' +
    '<DCCReference Include="ControlUnit.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
    'unit Unit1;'#13#10'interface'#13#10 +
    'type TRec = record ' + lField + ' end;'#13#10'var Rec: TRec;'#13#10 +
    'implementation'#13#10'procedure Run;'#13#10'begin'#13#10 +
    lBody + #13#10'end;'#13#10'end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'ControlUnit.pas'),
    'unit ControlUnit;'#13#10'interface'#13#10 +
    'type TRec = record Count: Integer; end;'#13#10'var Rec: TRec;'#13#10 +
    'implementation'#13#10'procedure Run; begin with Rec do Count := Count + 1; end;'#13#10 +
    'end.', TEncoding.ASCII);
  if aShape = 'ancestor-control' then
    // A distinct identity keeps this control independent of DS-721's homonym gap.
    TFile.WriteAllText(TPath.Combine(lRoot, 'ControlUnit.pas'),
      'unit ControlUnit;'#13#10'interface'#13#10 +
      'type TControlRec = record Count: Integer; end;'#13#10'var Rec: TControlRec;'#13#10 +
      'implementation'#13#10'procedure Run; begin with Rec do Count := Count + 1; end;'#13#10 +
      'end.', TEncoding.ASCII);
  if aShape = 'hidden-include' then
    TFile.WriteAllText(TPath.Combine(lRoot, 'Body.inc'), 'with Rec do Count := 5;', TEncoding.ASCII);
  if aShape = 'ancestor-control' then
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
      'unit Unit1;'#13#10'interface'#13#10 +
      'type TBase = class {$IF Declared(TBase)} Count: Integer; {$IFEND} end;'#13#10 +
      'TRec = class(TBase) end;'#13#10'var Rec: TRec;'#13#10 +
      'implementation'#13#10'procedure Run;'#13#10'begin'#13#10 + lBody +
      #13#10'end;'#13#10'end.', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.Combine(lRoot, 'P.dproj');
  begin
    lOptions.Configuration := 'Debug';
    lOptions.Platform := 'Win64';
    lOptions.DelphiVersion := '23.0';
  end;
  lOptions.Cache.SqliteCacheFileName := TPath.Combine(lRoot, 'round11-cache.sqlite');
  if TFile.Exists(lOptions.Cache.SqliteCacheFileName) then
    TFile.Delete(lOptions.Cache.SqliteCacheFileName);
  for lPass := 0 to 1 do
  begin
    lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
    lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
    lSnapshotPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWithCompatibilitySnapshot(lFacts);
    Assert.AreEqual(Length(lPlan.FinalStatements), Length(lSnapshotPlan.FinalStatements));
    for var i := 0 to High(lPlan.FinalStatements) do
    begin
      Assert.AreEqual(lPlan.FinalStatements[i].Status, lSnapshotPlan.FinalStatements[i].Status);
      Assert.AreEqual(lPlan.FinalStatements[i].Reason, lSnapshotPlan.FinalStatements[i].Reason);
      Assert.AreEqual(Length(lPlan.FinalStatements[i].Edits), Length(lSnapshotPlan.FinalStatements[i].Edits));
    end;
    Assert.AreEqual('planned', lPlan.Status, lPlan.Diagnostic);
    Assert.IsNotEmpty(lPlan.ContextFingerprint, 'Control statement retains its apply context.');
    lAffectedCount := 0;
    lFoundSkipped := False;
    lFoundControl := False;
    for lStatement in lPlan.FinalStatements do
      if SameText(ExtractFileName(lStatement.FileName), 'Unit1.pas') then
      begin
        // The declaration-owner refusal is retained separately under DS-721.
        if aShape = 'ancestor-control' then
        begin
          lFoundSkipped := True;
          Continue;
        end;
        Inc(lAffectedCount);
        begin
          Assert.AreEqual('skipped', lStatement.Status, 'Unknown declaration/activity cannot authorize apply.');
          Assert.AreEqual(lExpectedReason, lStatement.Reason);
          Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
          Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
          Assert.AreEqual('', lStatement.ReplacementText);
        end;
        lFoundSkipped := True;
      end else if SameText(ExtractFileName(lStatement.FileName), 'ControlUnit.pas') then
      begin
        Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
        Assert.IsTrue(Length(lStatement.Edits) > 0);
        lFoundControl := True;
      end;
    Assert.IsTrue(lFoundSkipped, 'Expected affected statement DTO.');
    Assert.IsTrue(lFoundControl, 'Expected unrelated known-active statement DTO.');
    // DAK transaction coverage consumes only planned FinalStatements with Edits.
    for lStatement in lPlan.FinalStatements do
      if (aShape <> 'ancestor-control') and SameText(lStatement.Status, 'planned') and
        (Length(lStatement.Edits) > 0) then
        Assert.IsFalse(SameText(ExtractFileName(lStatement.FileName), 'Unit1.pas'),
          'Fingerprint input must never include the refused source.');
  end;
end;

procedure TWithBinderTests.InactiveNestedWithShadowing(const aShape, aMode: string);
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticApiOptions;
  lPlan, lDiskPlan: TDelphiSemanticRemoveWithPlan;
  lStatement, lContainedStatement: TDelphiSemanticRemoveWithFinalStatement;
  lEdit: TDelphiSemanticRemoveWithEdit;
  lRoot, lSource, lInnerType, lBody: string;
begin
  lRoot := WithBinderTempPath('InactiveNested-' + aShape + '-' + aMode);
  TDirectory.CreateDirectory(lRoot);
  lInnerType := 'TRec';
  if MatchText(aShape, ['different', 'block']) then
    lInnerType := 'TOther';
  if MatchText(aShape, ['absent', 'multi', 'split', 'nested-span', 'nested-with']) then
    lInnerType := 'TAbsent';
  if aShape = 'unresolved' then
    lInnerType := 'TMissing';
  if aShape = 'call' then
    lInnerType := 'TGetter';
  lBody := 'with Inner do Count := 5;';
  if aShape = 'block' then
    lBody := 'with Inner do begin Other := 2; Count := 5; end;';
  if aShape = 'plain' then
    lBody := 'Count := 5;';
  if aShape = 'multi' then
    lBody := 'with Inner, Inner do Count := 5;';
  if aShape = 'comment' then
    lBody := '{ with Inner do Count := 99; } (* with Inner do *) Count := 5; // with Inner do';
  if aShape = 'string' then
    lBody := 'Count := Length(''with Inner do Count := 99;'');';
  if aShape = 'indexed' then
    lBody := 'with Inner[0] do Count := 5;';
  if aShape = 'deref' then
    lBody := 'with Inner^ do Count := 5;';
  if aShape = 'call' then
    lBody := 'with Inner() do Count := 5;';
  if aShape = 'split' then
    lBody := 'with'#13#10'      Inner do Count := 5;';
  if aShape = 'nested-with' then
    lBody := 'with Inner do with Inner do Count := 5;';
  if aShape = 'nested-span' then
    lBody := '{$IFDEF SECOND_TRACE} with Inner do Count := 5; {$ENDIF}';
  // DS-724 v4: lexical boundaries and hidden declarations do not weaken token refusal.
  if MatchText(aShape, ['inline-shadow', 'anonymous-shadow', 'fake-brace',
    'fake-star', 'fake-line', 'fake-string']) then
    lInnerType := 'TAbsent';
  if MatchText(aShape, ['header-active', 'header-active-lf']) then
    lBody := 'with Inner do {$ENDIF} Count := 5; {$IFDEF RELEASE_TRACE}';
  if aShape = 'header-active-ml' then
    lBody := 'with Inner do'#13#10'{$ENDIF}'#13#10'Count := 5; {$IFDEF RELEASE_TRACE}';
  if aShape = 'inline-shadow' then
    lBody := 'begin var Inner: TRec; with Inner do Count := 5; end;';
  if aShape = 'anonymous-shadow' then
    lBody := 'Action := procedure var Inner: TRec; begin with Inner do Count := 5; end;';
  if aShape = 'safe-before' then
    lBody := 'Count := 5; with Inner do Local := 2;';
  if aShape = 'safe-after' then
    lBody := 'with Inner do Local := 2; Count := 5;';
  if aShape = 'safe-two-spans' then
    lBody := 'Count := 5; {$ENDIF}{$IFDEF SECOND_TRACE} with Inner do Local := 2;';
  if aShape = 'fake-brace' then
    lBody := '{ literal {$IFDEF FAKE } with Inner do Count := 5;';
  if aShape = 'fake-star' then
    lBody := '(* literal {$IFDEF FAKE} *) with Inner do Count := 5;';
  if aShape = 'fake-line' then
    lBody := '// literal {$IFDEF FAKE}'#13#10'with Inner do Count := 5;';
  if aShape = 'fake-string' then
    lBody := 'Local := Length(''quote '''' {$IFDEF FAKE}''); with Inner do Count := 5;';
  if aShape = 'unicode-ident' then
    lBody := 'Count := '#$00D3'with;';
  if aShape = 'suffix-ident' then
    lBody := 'Count := withX;';
  if aShape = 'escaped-ident' then
    lBody := 'Count := &with;';
  // DS-724 v4: absence (c) still refuses; an inactive WITH token is sufficient.
  if StartsText('v3-', aShape) then
    lInnerType := 'TAbsent';
  if aShape = 'v3-simple' then
    lBody := 'Count := 8; with Inner do Local := 2; Count := 9;';
  if aShape = 'v3-if' then
    lBody := 'Count := 8; with Inner do if Local = 0 then Local := 2 else Local := 3; Count := 9;';
  lSource := 'unit Unit1;'#13#10'interface'#13#10 +
    'type TRec = record Count: Integer; Other: Integer; end;'#13#10 +
    'TOther = record Count: Integer; end;'#13#10 +
    'TAbsent = record Value: Integer; end;'#13#10 +
    'TGetter = function: TRec;'#13#10 +
    'var Rec: TRec;'#13#10'Inner: ' + lInnerType + ';'#13#10 +
    'implementation'#13#10'procedure Run;'#13#10'begin'#13#10 +
    '  with Rec do begin'#13#10'    Count := 1;'#13#10 +
    '    {$IFDEF RELEASE_TRACE}'#13#10'    ' + lBody + #13#10 +
    '    {$ENDIF}'#13#10'  end;'#13#10'end;'#13#10'end.'#13#10;
  if StartsText('header-active', aShape) or MatchText(aShape,
    ['inline-shadow', 'anonymous-shadow', 'safe-before', 'safe-after', 'safe-two-spans',
    'fake-brace', 'fake-star', 'fake-line', 'fake-string', 'unicode-ident',
    'suffix-ident', 'escaped-ident']) then
    lSource := StringReplace(lSource, 'implementation',
      'Local: Integer;'#13#10'Action: TProc;'#13#10 +
      #$00D3'with: Integer;'#13#10'withX: Integer;'#13#10'&with: Integer;'#13#10 +
      'implementation', []);
  if StartsText('v3-', aShape) then
    lSource := StringReplace(lSource, 'implementation', 'Local: Integer;'#13#10'implementation', []);
  if aShape = 'v3-routine-var' then
    lSource := StringReplace(lSource, 'procedure Run;'#13#10'begin',
      'procedure Run;'#13#10'var {$IFDEF RELEASE_TRACE} Inner: TRec; {$ENDIF} Local2: Integer;'#13#10'begin', []);
  if aShape = 'v3-global-else' then
    lSource := StringReplace(lSource, 'Inner: TAbsent;',
      '{$IFDEF RELEASE_TRACE} Inner: TRec; {$ELSE} Inner: TAbsent; {$ENDIF}', []);
  if aShape = 'v3-record-field' then
    lSource := StringReplace(lSource, 'TAbsent = record Value: Integer; end;',
      'TAbsent = record Value: Integer; {$IFDEF RELEASE_TRACE} Count: Integer; {$ENDIF} end;', []);
  if aShape = 'v3-inline-before' then
    lSource := StringReplace(lSource, '  with Rec do begin',
      '  {$IFDEF RELEASE_TRACE} var Inner: TRec; {$ENDIF}'#13#10'  with Rec do begin', []);
  if aShape = 'v3-routine-before' then
    lSource := StringReplace(lSource, 'procedure Run;'#13#10'begin',
      'procedure Run;'#13#10'var {$IFDEF RELEASE_TRACE} Inner: TRec; {$ENDIF} Local2: Integer;'#13#10'begin', []);
  if aShape = 'header-active-lf' then
    lSource := StringReplace(lSource, #13#10, #10, [rfReplaceAll]);
  if aShape = 'unknown' then
    lSource := StringReplace(lSource, '{$IFDEF RELEASE_TRACE}', '{$IF UseFast}', []);
  if aShape = 'active' then
    lSource := StringReplace(lSource, '{$IFDEF RELEASE_TRACE}', '{$IFNDEF RELEASE_TRACE}', []);
  // DS-724 v4: token presence refuses even when the nested body rewrites no name.
  // safe-before/safe-after/safe-two-spans and v3-simple/v3-if now refuse.
  if StartsText('v4-', aShape) then
  begin
    if aShape = 'v4-include-short' then
      lBody := '{$IFDEF RELEASE_TRACE}{$I prefix.inc}{$ENDIF} Count := 5;';
    if aShape = 'v4-include-long' then
      lBody := '{$IFDEF RELEASE_TRACE}{$INCLUDE prefix.inc}{$ENDIF} Count := 5;';
    if aShape = 'v4-include-active' then
      lBody := 'Count := 5;';
    if aShape = 'v4-sibling' then
      lBody := '{$IFDEF RELEASE_TRACE} with Inner do {$ENDIF} with Absent do Count := 5;';
    if aShape = 'v4-active-sub' then
      lBody := '{$IFDEF RELEASE_TRACE} with Inner do {$ENDIF} with Sub do V := 1;';
    if aShape = 'v4-sol-sibling' then
      lBody := '{$IFDEF RELEASE_TRACE} with Hidden do {$ENDIF} with Inner do Count := 5;';
    if aShape = 'v4-comma' then
      lBody := '{$IFDEF RELEASE_TRACE} with Inner, Sub do Local := V; {$ENDIF}';
    if aShape = 'v4-comma-noref' then
      lBody := '{$IFDEF RELEASE_TRACE} with Inner, Sub do Local := 2; {$ENDIF}';
    if aShape = 'v4-comma-absent' then
      lBody := '{$IFDEF RELEASE_TRACE} with Absent, Sub do Local := 2; {$ENDIF}';
    if aShape = 'v4-no-outer-ref' then
      lBody := '{$IFDEF RELEASE_TRACE} with Inner do Local := 2; {$ENDIF}';
    if aShape = 'v4-fake-brace' then
      lBody := '{$IFDEF RELEASE_TRACE} { literal {$IFDEF FAKE } Local := 2; {$ENDIF} Count := 9;';
    if aShape = 'v4-fake-star' then
      lBody := '{$IFDEF RELEASE_TRACE} (* literal {$IFDEF FAKE} with Inner do *) Local := 2; {$ENDIF} Count := 9;';
    if aShape = 'v4-fake-line' then
      lBody := '{$IFDEF RELEASE_TRACE} // literal {$IFDEF FAKE} with Inner do'#13#10'Local := 2; {$ENDIF} Count := 9;';
    if aShape = 'v4-fake-string' then
      lBody := '{$IFDEF RELEASE_TRACE} Local := Length(''quote '''' {$IFDEF FAKE} with Inner do''); {$ENDIF} Count := 9;';
    if aShape = 'v4-outside' then
      lBody := 'Count := 9;';
    if aShape = 'v4-prefix-ident' then
      lBody := '{$IFDEF RELEASE_TRACE} Local := withdraw; {$ENDIF} Count := 9;';
    lSource := 'unit Unit1;'#13#10'interface'#13#10 +
      'type TSub = record V: Integer; end;'#13#10 +
      'TRec = record Count: Integer; Other: Integer; Sub: TSub; end;'#13#10 +
      'TOuter = record Count: Integer; Inner: TRec; end;'#13#10 +
      'TAbsent = record Value: Integer; end;'#13#10 +
      'var Rec: TRec;'#13#10'Inner: TRec;'#13#10'Hidden: TOuter;'#13#10 +
      'Absent: TAbsent;'#13#10'Local: Integer;'#13#10'withdraw: Integer;'#13#10 +
      'implementation'#13#10'procedure Run;'#13#10'begin'#13#10 +
      '  with Rec do begin'#13#10'    Count := 1;'#13#10 +
      '    ' + lBody + #13#10'  end;'#13#10'end;'#13#10'end.'#13#10;
    if aShape = 'v4-sol-sibling' then
      lSource := StringReplace(lSource, 'Rec: TRec;', 'Rec: TOuter;', []);
    if aShape = 'v4-no-outer-ref' then
      lSource := StringReplace(lSource, '    Count := 1;'#13#10, '', []);
    if aShape = 'v4-outside' then
      lSource := StringReplace(lSource, '  with Rec do begin',
        '  {$IFDEF RELEASE_TRACE} with Inner do Local := 2; {$ENDIF}'#13#10 +
        '  with Rec do begin', []);
  end;
  // DS-724 polish: retain the round-5 deep/sibling and directive fixtures.
  if StartsText('v4-polish-', aShape) then
  begin
    if aShape = 'v4-polish-d-deep-sibling' then
      lBody := '  with Oth do begin'#13#10 +
        '    with Rec do begin'#13#10 +
        '      with Absent do begin'#13#10 +
        '        {$IFDEF RELEASE_TRACE} with Inner do {$ENDIF} Local := Value;'#13#10 +
        '      end;'#13#10 +
        '      with Absent do Count := 5;'#13#10 +
        '      with Absent do begin with Absent do Count := 6; end;'#13#10 +
        '    end;'#13#10 +
        '  end;'#13#10;
    if aShape = 'v4-polish-i-lower' then
      lBody := '  with Rec do begin'#13#10 +
        '    Count := 1;'#13#10 +
        '    {$IFDEF RELEASE_TRACE}{$i x.inc}{$ENDIF} Count := 5;'#13#10 +
        '  end;'#13#10;
    if aShape = 'v4-polish-i-paren' then
      lBody := '  with Rec do begin'#13#10 +
        '    Count := 1;'#13#10 +
        '    {$IFDEF RELEASE_TRACE}(*$I x.inc*){$ENDIF} Count := 5;'#13#10 +
        '  end;'#13#10;
    if aShape = 'v4-polish-i-quoted-space' then
      lBody := '  with Rec do begin'#13#10 +
        '    Count := 1;'#13#10 +
        '    {$IFDEF RELEASE_TRACE}{$I ''my file.inc''}{$ENDIF} Count := 5;'#13#10 +
        '  end;'#13#10;
    if aShape = 'v4-polish-i-include-quoted-space' then
      lBody := '  with Rec do begin'#13#10 +
        '    Count := 1;'#13#10 +
        '    {$IFDEF RELEASE_TRACE}{$INCLUDE ''my file.inc''}{$ENDIF} Count := 5;'#13#10 +
        '  end;'#13#10;
    if aShape = 'v4-polish-x-switch-plus' then
      lBody := '  with Rec do begin'#13#10 +
        '    Count := 1;'#13#10 +
        '    {$IFDEF RELEASE_TRACE}{$I+}{$ENDIF} Count := 5;'#13#10 +
        '  end;'#13#10;
    if aShape = 'v4-polish-x-switch-minus' then
      lBody := '  with Rec do begin'#13#10 +
        '    Count := 1;'#13#10 +
        '    {$IFDEF RELEASE_TRACE}{$I-}{$ENDIF} Count := 5;'#13#10 +
        '  end;'#13#10;
    if aShape = 'v4-polish-x-inline' then
      lBody := '  with Rec do begin'#13#10 +
        '    Count := 1;'#13#10 +
        '    {$IFDEF RELEASE_TRACE}{$INLINE ON}{$ENDIF} Count := 5;'#13#10 +
        '  end;'#13#10;
    lSource := 'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses System.SysUtils;'#13#10 +
      'type'#13#10 +
      '  TSub = record V: Integer; end;'#13#10 +
      '  TRec = record Count: Integer; Other: Integer; Sub: TSub; end;'#13#10 +
      '  TInner = record Count: Integer; Sub: TSub; end;'#13#10 +
      '  TOth = record Count: Integer; end;'#13#10 +
      '  TAbsent = record Value: Integer; end;'#13#10 +
      'var'#13#10 +
      '  Rec: TRec;'#13#10 +
      '  Inner: TInner;'#13#10 +
      '  Oth: TOth;'#13#10 +
      '  Absent: TAbsent;'#13#10 +
      '  Local: Integer;'#13#10 +
      '  Flag, Flag2: Boolean;'#13#10 +
      ''#13#10 +
      'procedure Run;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      ''#13#10 +
      'begin'#13#10 +
      lBody + 'end;'#13#10 +
      'end.'#13#10;
    TFile.WriteAllText(TPath.Combine(lRoot, 'x.inc'), 'with Inner do', TEncoding.ASCII);
    TFile.WriteAllText(TPath.Combine(lRoot, 'my file.inc'), 'with Inner do', TEncoding.ASCII);
  end;
  // DS-724 fix4: inactive includes can hide a WITH header in another build.
  TFile.WriteAllText(TPath.Combine(lRoot, 'prefix.inc'), 'with Inner do', TEncoding.ASCII);
  if aShape = 'v4-include-active' then
  begin
    TFile.WriteAllText(TPath.Combine(lRoot, 'active.inc'),
      'const IncludedValue = 1;', TEncoding.ASCII);
    lSource := StringReplace(lSource, 'procedure Run;',
      '{$I active.inc}'#13#10'procedure Run;', []);
  end;
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P; uses Unit1; begin end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dproj'),
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="Unit1.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'), lSource, TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.Combine(lRoot, 'P.dproj');
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win64';
  lOptions.DelphiVersion := '23.0';
  lOptions.Cache.SqliteCacheFileName := TPath.Combine(lRoot, 'cache.sqlite');
  if TFile.Exists(lOptions.Cache.SqliteCacheFileName) then
    TFile.Delete(lOptions.Cache.SqliteCacheFileName);
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  if aMode = 'warm' then
  begin
    lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
    Assert.IsTrue(lFacts.Metrics.SemanticCacheHits > 0, 'Warm SQLite facts must hit.');
  end;
  if aMode = 'snapshot' then
    lDiskPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWithCompatibilitySnapshot(lFacts)
  else
    lDiskPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
  // Rebind the same cold/reloaded models with the source absent. Discovery and
  // the discovery pass must consume stored facts rather than reopen files.
  TFile.Delete(TPath.Combine(lRoot, 'Unit1.pas'));
  try
    lFacts := TDelphiSemanticWithBinder.BindProject(lFacts.ContextFingerprint, nil, lFacts.UnitModels);
  finally
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'), lSource, TEncoding.UTF8);
  end;
  // The existing planner separately validates source ranges against the file.
  if aMode = 'snapshot' then
    lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWithCompatibilitySnapshot(lFacts)
  else
    lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
  Assert.IsTrue(Length(lDiskPlan.FinalStatements) > 0, aShape + ':' + aMode);
  Assert.AreEqual(Length(lDiskPlan.FinalStatements), Length(lPlan.FinalStatements), aShape + ':' + aMode);
  Assert.AreEqual(lDiskPlan.FinalStatements[0].Status, lPlan.FinalStatements[0].Status);
  Assert.AreEqual(lDiskPlan.FinalStatements[0].Reason, lPlan.FinalStatements[0].Reason);
  Assert.AreEqual(lDiskPlan.FinalStatements[0].SafetyReason, lPlan.FinalStatements[0].SafetyReason);
  Assert.AreEqual(lDiskPlan.FinalStatements[0].ReplacementText, lPlan.FinalStatements[0].ReplacementText);
  Assert.AreEqual(Length(lDiskPlan.FinalStatements), Length(lPlan.FinalStatements), aShape + ':' + aMode);
  lStatement := lPlan.FinalStatements[0];
  // DS-724 v4: all real inactive WITH tokens refuse, including absence (c),
  // safe-before/after/two-spans, v3-simple and the round-2 sol v3-if control.
  if MatchText(aShape, ['active', 'plain', 'comment', 'string', 'unicode-ident',
    'suffix-ident', 'v4-prefix-ident', 'v4-fake-brace', 'v4-fake-star',
    'v4-fake-line', 'v4-fake-string', 'v4-outside', 'v4-include-active',
    'v4-polish-x-switch-plus', 'v4-polish-x-switch-minus', 'v4-polish-x-inline']) then
  begin
    Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
    Assert.AreEqual('', lStatement.Reason);
    Assert.AreEqual('', lStatement.SafetyReason);
    Assert.IsTrue(Length(lStatement.Edits) > 0);
    Assert.IsTrue(Pos('lWithRecPtr^.Count := 1', lStatement.ReplacementText) > 0);
    // Matched native 45b619b probes pin these negative controls exactly.
    if aShape = 'v4-polish-x-switch-plus' then
    begin
      Assert.AreEqual('planned', lPlan.Status);
      Assert.AreEqual(1, Integer(Length(lPlan.FinalStatements)));
      Assert.AreEqual(2, Integer(Length(lStatement.Edits)));
      Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
      Assert.AreEqual('  lWithRecPtr := @Rec;'#13#10 +
        ' begin'#13#10 +
        '    lWithRecPtr^.Count := 1;'#13#10 +
        '    {$IFDEF RELEASE_TRACE}{$I+}{$ENDIF} lWithRecPtr^.Count := 5;'#13#10 +
        '  end;',
        lStatement.ReplacementText);
    end;
    if aShape = 'v4-polish-x-switch-minus' then
    begin
      Assert.AreEqual('planned', lPlan.Status);
      Assert.AreEqual(1, Integer(Length(lPlan.FinalStatements)));
      Assert.AreEqual(2, Integer(Length(lStatement.Edits)));
      Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
      Assert.AreEqual('  lWithRecPtr := @Rec;'#13#10 +
        ' begin'#13#10 +
        '    lWithRecPtr^.Count := 1;'#13#10 +
        '    {$IFDEF RELEASE_TRACE}{$I-}{$ENDIF} lWithRecPtr^.Count := 5;'#13#10 +
        '  end;',
        lStatement.ReplacementText);
    end;
    if aShape = 'v4-polish-x-inline' then
    begin
      Assert.AreEqual('planned', lPlan.Status);
      Assert.AreEqual(1, Integer(Length(lPlan.FinalStatements)));
      Assert.AreEqual(2, Integer(Length(lStatement.Edits)));
      Assert.AreEqual(1, Integer(Length(lStatement.Temps)));
      Assert.AreEqual('  lWithRecPtr := @Rec;'#13#10 +
        ' begin'#13#10 +
        '    lWithRecPtr^.Count := 1;'#13#10 +
        '    {$IFDEF RELEASE_TRACE}{$INLINE ON}{$ENDIF} lWithRecPtr^.Count := 5;'#13#10 +
        '  end;',
        lStatement.ReplacementText);
    end;
    if aShape = 'active' then
      Assert.IsTrue(Pos('lWithRecPtr1^.Count := 5', lStatement.ReplacementText) > 0);
    if MatchText(aShape, ['plain', 'comment']) then
      Assert.IsTrue(Pos('lWithRecPtr^.Count := 5', lStatement.ReplacementText) > 0);
  end else begin
    Assert.AreEqual('skipped', lStatement.Status, aShape + ':' + aMode);
    if aShape = 'escaped-ident' then
      Assert.AreEqual('symbol-not-found', lStatement.Reason)
    else if aShape = 'unknown' then
    begin
      Assert.AreEqual('activity-unverified', lStatement.Reason);
      Assert.AreEqual('ACTIVITY_UNVERIFIED', lStatement.SafetyReason);
    end else begin
      Assert.AreEqual('inactive-nested-with-shadowing', lStatement.Reason);
      Assert.AreEqual('INACTIVE_NESTED_WITH_SHADOW', lStatement.SafetyReason);
    end;
    Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
    Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
    Assert.AreEqual('', lStatement.ReplacementText);
    if aShape <> 'escaped-ident' then
    begin
      for lEdit in lPlan.Edits do
        Assert.IsFalse(lEdit.StatementId = lStatement.SemanticId, 'Refused candidate must be absent.');
      if lStatement.SafetyReason = 'INACTIVE_NESTED_WITH_SHADOW' then
        for lContainedStatement in lPlan.FinalStatements do
        begin
          Assert.AreEqual('skipped', lContainedStatement.Status, 'Contained WITH must refuse: ' + aShape);
          Assert.AreEqual('inactive-nested-with-shadowing', lContainedStatement.Reason);
          Assert.AreEqual('INACTIVE_NESTED_WITH_SHADOW', lContainedStatement.SafetyReason);
          Assert.AreEqual(0, Integer(Length(lContainedStatement.Edits)));
          Assert.AreEqual(0, Integer(Length(lContainedStatement.Temps)));
          Assert.AreEqual('', lContainedStatement.ReplacementText);
          for lEdit in lPlan.Edits do
            Assert.IsFalse(lEdit.StatementId = lContainedStatement.SemanticId,
              'Contained refusal must remove its candidate edit.');
        end;
      Assert.AreEqual(0, Integer(Length(lPlan.Edits)), 'Refused candidate must be absent.');
    end;
  end;
  Assert.AreEqual(lSource, TFile.ReadAllText(TPath.Combine(lRoot, 'Unit1.pas')));
end;

procedure TWithBinderTests.WholeWithRangeRefusesOnlyUnknownActivity(const aShape: string);
var
  lOptions: TDelphiSemanticApiOptions;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lPlan, lSnapshotPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
  lRoot, lSource: string;
  lPass: Integer;
begin
  lRoot := WithBinderTempPath('RangeKnownOrUnknown-' + aShape);
  TDirectory.CreateDirectory(lRoot);
  lSource := 'unit Unit1;'#13#10'interface'#13#10 +
    'type TRec = record Count: Integer; end;'#13#10 +
    'var Rec, Inner: TRec;'#13#10'implementation'#13#10 +
    'procedure Run;'#13#10'begin'#13#10 +
    '  with Rec do begin'#13#10'    Count := 1;'#13#10 +
    '    {$IFDEF RELEASE_TRACE}'#13#10 +
    '    with Inner do Count := 5;'#13#10 +
    '    {$ENDIF}'#13#10'  end;'#13#10'end;'#13#10'end.'#13#10;
  if aShape = 'unknown' then
    lSource := StringReplace(lSource, '{$IFDEF RELEASE_TRACE}', '{$IF UseFast}', []);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P; uses Unit1; begin end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dproj'),
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="Unit1.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'), lSource, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.Combine(lRoot, 'P.dproj');
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win64';
  lOptions.DelphiVersion := '23.0';
  lOptions.Cache.SqliteCacheFileName := TPath.Combine(lRoot, 'range-cache.sqlite');
  if TFile.Exists(lOptions.Cache.SqliteCacheFileName) then
    TFile.Delete(lOptions.Cache.SqliteCacheFileName);
  for lPass := 0 to 1 do
  begin
    lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
    lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
    lSnapshotPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWithCompatibilitySnapshot(lFacts);
    Assert.AreEqual(1, Integer(Length(lPlan.FinalStatements)));
    Assert.AreEqual(1, Integer(Length(lSnapshotPlan.FinalStatements)));
    lStatement := lPlan.FinalStatements[0];
    Assert.AreEqual(lStatement.Status, lSnapshotPlan.FinalStatements[0].Status);
    Assert.AreEqual(lStatement.Reason, lSnapshotPlan.FinalStatements[0].Reason);
    Assert.AreEqual(lStatement.SafetyReason, lSnapshotPlan.FinalStatements[0].SafetyReason);
    Assert.AreEqual(lStatement.ReplacementText, lSnapshotPlan.FinalStatements[0].ReplacementText);
    Assert.AreEqual(Length(lStatement.Edits), Length(lSnapshotPlan.FinalStatements[0].Edits));
    Assert.AreEqual(Length(lStatement.Temps), Length(lSnapshotPlan.FinalStatements[0].Temps));
    if aShape = 'known' then
    begin
      Assert.AreEqual('planned', lPlan.Status);
      Assert.AreEqual(lPlan.ContextFingerprint, lSnapshotPlan.ContextFingerprint);
      Assert.IsNotEmpty(lPlan.ContextFingerprint);
      // DS-724 v4: an inactive WITH token refuses; enabling it can bind Count to Inner.
      Assert.AreEqual('skipped', lStatement.Status);
      Assert.AreEqual('inactive-nested-with-shadowing', lStatement.Reason);
      Assert.AreEqual('INACTIVE_NESTED_WITH_SHADOW', lStatement.SafetyReason);
      Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
      Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
      Assert.AreEqual('', lStatement.ReplacementText);
    end else begin
      Assert.AreEqual('skipped', lStatement.Status);
      Assert.AreEqual('activity-unverified', lStatement.Reason);
      Assert.AreEqual('ACTIVITY_UNVERIFIED', lStatement.SafetyReason);
      Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
      Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
      Assert.AreEqual('', lStatement.ReplacementText);
      // Apply consumes only planned final DTOs with edits, not the plan-wide seal.
      Assert.AreEqual(lPlan.ContextFingerprint, lSnapshotPlan.ContextFingerprint);
    end;
    Assert.AreEqual(lSource, TFile.ReadAllText(TPath.Combine(lRoot, 'Unit1.pas')));
  end;
end;

procedure TWithBinderTests.PublicProviderFingerprintFailureRefuses(const aPath: string);
var
  lOptions: TDelphiSemanticApiOptions;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lContext: TDelphiSemanticContextResult;
  lSession: TDelphiSemanticProjectSessionResult;
  lDiagnostics: TArray<TDelphiSemanticDiagnostic>;
begin
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.GetFullPath(TPath.Combine(RepoRoot,
    '..\DelphiAiKit\tests\fixtures\RemoveWithMultipleSelectorRewriteFixture\' +
    'RemoveWithMultipleSelectorRewriteFixture.dproj'));
  lOptions.ImplicitRootMemberAbsence := TThrowingRootAbsenceProvider.Create('fingerprint');
  try
    if aPath = 'plan' then
    begin
      lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lOptions);
      Assert.AreNotEqual('planned', lPlan.Status);
      Assert.AreEqual('', lPlan.ContextFingerprint);
      lDiagnostics := lPlan.Diagnostics;
    end else if aPath = 'project' then
    begin
      lContext := TDelphiSemanticProject.Load(lOptions.ProjectFileName,
        ProjectOptionsFromApiOptions(lOptions));
      Assert.IsFalse(lContext.Success);
      Assert.AreEqual('', lContext.Project.ContextFingerprint);
      lDiagnostics := lContext.Diagnostics;
    end else begin
      lSession := TDelphiSemanticProjectSession.Open(ProjectOptionsFromApiOptions(lOptions));
      try
        Assert.IsFalse(lSession.Success);
        Assert.IsTrue(lSession.Session = nil);
        lDiagnostics := lSession.Diagnostics;
      finally
        lSession.Session.Free;
      end;
    end;
  except
    on E: Exception do
      Assert.Fail('The public provider boundary threw: ' + E.Message);
  end;
  Assert.AreEqual(1, Integer(Length(lDiagnostics)));
  Assert.AreEqual('IMPLICIT_ROOT_PROVIDER_FAILED', lDiagnostics[0].Code);
  Assert.IsTrue(Pos('Fingerprint unavailable', lDiagnostics[0].Message) > 0);
end;

procedure TWithBinderTests.OptionalRootAbsenceFlowsThroughApiAndBypassesPersistentFacts;
var
  lBuildResult: TDelphiSemanticRemoveWithPlanBuildResult;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lConnection: TFDConnection;
  lDriverLink: TFDPhysSQLiteDriverLink;
  lDefaultIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lDefaultPlan: TDelphiSemanticRemoveWithPlan;
  lEvidenceIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lProjectOptions: TDelphiSemanticOptions;
  lSeedSnapshot: TDelphiProjectSnapshot;
  lSession: TDelphiSemanticProjectSessionResult;
  lOptions: TDelphiSemanticApiOptions;
  lPlan: TDelphiSemanticRemoveWithPlan;
begin
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.GetFullPath(TPath.Combine(RepoRoot,
    '..\DelphiAiKit\tests\fixtures\RemoveWithMultipleSelectorRewriteFixture\' +
    'RemoveWithMultipleSelectorRewriteFixture.dproj'));
  lOptions.Cache.SqliteCacheFileName := WithBinderTempPath('RootAbsenceProjectCache.sqlite');
  lDefaultPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lOptions);
  Assert.AreEqual(2, Integer(Length(lDefaultPlan.FinalStatements)));
  Assert.AreEqual('skipped', lDefaultPlan.FinalStatements[0].Status);
  Assert.AreEqual('planned', lDefaultPlan.FinalStatements[1].Status);
  lProjectOptions := ProjectOptionsFromApiOptions(lOptions);
  lSession := TDelphiSemanticProjectSession.Open(lProjectOptions);
  try
    Assert.IsTrue(lSession.Success);
    lDefaultIdentity := ProjectRemoveWithFactsIdentityForTest(lSession.Session.Project, lProjectOptions);
  finally
    lSession.Session.Free;
  end;
  lOptions.ImplicitRootMemberAbsence := TImplicitRootAbsenceStub.Create;
  lProjectOptions := ProjectOptionsFromApiOptions(lOptions);
  lSession := TDelphiSemanticProjectSession.Open(lProjectOptions);
  try
    Assert.IsTrue(lSession.Success);
    lEvidenceIdentity := ProjectRemoveWithFactsIdentityForTest(lSession.Session.Project, lProjectOptions);
  finally
    lSession.Session.Free;
  end;
  lCache := TDelphiSemanticSnapshotSqliteCache.Create(lOptions.Cache.SqliteCacheFileName);
  lSeedSnapshot := nil;
  try
    Assert.IsTrue(lCache.TryLoadProjectRemoveWithPlanningFacts(lDefaultIdentity, lSeedSnapshot));
    lCache.StoreProjectRemoveWithPlanningFacts(lEvidenceIdentity, lSeedSnapshot);
  finally
    lSeedSnapshot.Free;
    lCache.Free;
  end;
  lDriverLink := TFDPhysSQLiteDriverLink.Create(nil);
  lConnection := TFDConnection.Create(nil);
  try
    lConnection.LoginPrompt := False;
    lConnection.Params.Values['DriverID'] := 'SQLite';
    lConnection.Params.Values['Database'] := lOptions.Cache.SqliteCacheFileName;
    lConnection.Connected := True;
    lConnection.ExecSQL('create table root_absence_write_audit (event text not null)');
    lConnection.ExecSQL('create trigger root_absence_insert after insert on ' +
      'snapshot_project_remove_with_facts begin insert into root_absence_write_audit ' +
      'values (''insert''); end');
    lConnection.ExecSQL('create trigger root_absence_update after update on ' +
      'snapshot_project_remove_with_facts begin insert into root_absence_write_audit ' +
      'values (''update''); end');
    lConnection.ExecSQL('create trigger root_absence_delete after delete on ' +
      'snapshot_project_remove_with_facts begin insert into root_absence_write_audit ' +
      'values (''delete''); end');
    lConnection.Connected := False;
    lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lOptions);
    Assert.AreEqual(2, Integer(Length(lPlan.FinalStatements)),
      'Optional evidence must reach the binder through API and project session.');
    Assert.AreEqual('planned', lPlan.FinalStatements[0].Status);
    Assert.AreEqual('planned', lPlan.FinalStatements[1].Status);
    Assert.AreNotEqual(lDefaultPlan.ContextFingerprint, lPlan.ContextFingerprint);
    lConnection.Connected := True;
    Assert.AreEqual(0, Integer(lConnection.ExecSQLScalar(
      'select count(*) from root_absence_write_audit')),
      'The API provider request must bypass every persistent planning-fact write.');
    lConnection.Connected := False;
    // The exact provider-context entry must remain the seeded default refusal.
    // Probe metrics also catch a forbidden cache read that subsequently rebinds.
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lOptions.Cache.SqliteCacheFileName);
    lSeedSnapshot := nil;
    try
      Assert.IsTrue(lCache.TryLoadProjectRemoveWithPlanningFacts(lEvidenceIdentity, lSeedSnapshot));
      lDefaultPlan := TDelphiSemanticRemoveWithPlanner.Plan(lSeedSnapshot);
      Assert.AreEqual('skipped', lDefaultPlan.FinalStatements[0].Status,
        'Provider-backed WITH facts must bypass persistent writes.');
    finally
      lSeedSnapshot.Free;
      lCache.Free;
    end;
    lSession := TDelphiSemanticProjectSession.Open(lProjectOptions);
    try
      Assert.IsTrue(lSession.Success);
      lBuildResult := lSession.Session.PlanRemoveWithResult;
      Assert.AreEqual(0, lBuildResult.SnapshotMetrics.SnapshotCacheProbes,
        'Provider-backed WITH facts must bypass persistent reads, including rebind-on-hit.');
    finally
      lSession.Session.Free;
    end;
    lConnection.Connected := True;
    Assert.AreEqual(0, Integer(lConnection.ExecSQLScalar(
      'select count(*) from root_absence_write_audit')),
      'Provider-backed WITH facts must bypass every persistent planning-fact write.');
  finally
    lConnection.Free;
    lDriverLink.Free;
  end;
  lOptions.ImplicitRootMemberAbsence := nil;
  lDefaultPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lOptions);
  Assert.AreEqual(2, Integer(Length(lDefaultPlan.FinalStatements)),
    'Provider-backed facts must never contaminate the default persistent cache.');
  Assert.AreEqual('skipped', lDefaultPlan.FinalStatements[0].Status);
  Assert.AreEqual('planned', lDefaultPlan.FinalStatements[1].Status);
end;

procedure TWithBinderTests.UnindexedRecordHelperRequiresVisibleMatchingIdentity(const aShape: string);
var
  lRoot: string;
function Unit_(const aName, aText: string): TDelphiSemanticUnitModel;
var
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := TPath.Combine(lRoot, aName + '.pas');
  TFile.WriteAllText(lOptions.SourceFileName, aText, TEncoding.ASCII);
  Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(Result.Success, aName);
  Assert.AreEqual('ast', Result.ScopeModelStatus);
end;
procedure Report(const aCase: string; const aModels: TArray<TDelphiSemanticUnitModel>);
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lPlan, lSnapshotPlan: TDelphiSemanticRemoveWithPlan;
  lReference: TDelphiSemanticBoundReference;
  lEdit: TDelphiSemanticRemoveWithEdit;
  lExpectedClass, lExpectedReason, lExpectedSafety, lExpectedStatus, lName: string;
  lExpectedEdits, lBindingIndex, lStatementIndex, lExpectedCount: Integer;
begin
  lFacts := TDelphiSemanticWithBinder.BindProject('ds720-' + aShape, nil, aModels);
  lExpectedCount := 1;
  if aShape = 'nested' then
  begin
    lExpectedCount := 2;
  end;
  Assert.AreEqual(lExpectedCount, Integer(Length(lFacts.Bindings)));
  lBindingIndex := lExpectedCount - 1;
  Assert.AreEqual('resolved', lFacts.Bindings[lBindingIndex].Selectors[0].Status);
  lExpectedClass := 'unsupported';
  lExpectedStatus := 'skipped';
  lExpectedReason := 'receiver-member-not-found';
  lExpectedSafety := 'RECORD_HELPER_MEMBERS_UNVERIFIED';
  lExpectedEdits := 0;
  lName := 'Count';
  if MatchText(aShape, ['call', 'intrinsic']) then
  begin
    lExpectedReason := 'symbol-not-found';
  end;
  if MatchText(aShape, ['unrelated', 'class-helper', 'local-array', 'no-helper']) then
  begin
    lExpectedStatus := 'planned';
    lExpectedReason := '';
    lExpectedSafety := '';
    lExpectedEdits := 2;
    lExpectedClass := 'lexical';
  end;
  if MatchText(aShape, ['same-name', 'private-import', 'import', 'indexed-import']) then
  begin
    lExpectedReason := 'type-source-not-indexed';
    lExpectedSafety := lExpectedReason;
    if aShape <> 'import' then
    begin
      lExpectedClass := 'lexical';
    end;
  end;
  if aShape = 'after-site' then
  begin
    lExpectedClass := 'lexical';
    lExpectedReason := 'receiver-member-owner-conflict';
    lExpectedSafety := lExpectedReason;
  end;
  if aShape = 'indexed-import' then
  begin
    lExpectedClass := 'member';
  end;
  if MatchText(aShape, ['intrinsic', 'no-helper']) then
  begin
    lName := 'FillChar';
    if aShape = 'no-helper' then
    begin
      lExpectedClass := 'intrinsic';
    end;
  end;
  if aShape = 'local-array' then
  begin
    lName := 'lArr[0]';
    lExpectedClass := 'unsupported';
  end;
  Assert.IsTrue(HasReference(lFacts.Bindings[lBindingIndex], lName, lExpectedClass), aShape + ': ' + lName);
  for lReference in lFacts.Bindings[lBindingIndex].References do
  begin
    if SameText(lReference.Name, lName) and (lExpectedClass = 'unsupported') then
    begin
      if aShape = 'local-array' then
      begin
        Assert.AreEqual('INDEXED_SELECTOR_UNSUPPORTED', lReference.ReasonCode);
      end else begin
        Assert.AreEqual('RECORD_HELPER_MEMBERS_UNVERIFIED', lReference.ReasonCode);
      end;
    end;
  end;
  lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
  Assert.AreEqual(lExpectedCount, Integer(Length(lPlan.FinalStatements)));
  for lStatementIndex := 0 to High(lPlan.FinalStatements) do
  begin
    Assert.AreEqual(lExpectedStatus, lPlan.FinalStatements[lStatementIndex].Status, aShape);
    Assert.AreEqual(lExpectedReason, lPlan.FinalStatements[lStatementIndex].Reason, aShape);
    Assert.AreEqual(lExpectedSafety, lPlan.FinalStatements[lStatementIndex].SafetyReason, aShape);
    Assert.AreEqual(lExpectedEdits, Integer(Length(lPlan.FinalStatements[lStatementIndex].Edits)), aShape);
    if lExpectedSafety = 'RECORD_HELPER_MEMBERS_UNVERIFIED' then
    begin
      Assert.AreEqual(0, Integer(Length(lPlan.FinalStatements[lStatementIndex].Temps)));
      Assert.AreEqual('', lPlan.FinalStatements[lStatementIndex].ReplacementText);
      for lEdit in lPlan.Edits do
      begin
        Assert.AreNotEqual('remove-with-candidate', lEdit.Kind);
      end;
    end;
    lSnapshotPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWithCompatibilitySnapshot(lFacts);
    Assert.AreEqual(lPlan.FinalStatements[lStatementIndex].Status, lSnapshotPlan.FinalStatements[lStatementIndex].Status);
    Assert.AreEqual(lPlan.FinalStatements[lStatementIndex].Reason, lSnapshotPlan.FinalStatements[lStatementIndex].Reason);
    Assert.AreEqual(lPlan.FinalStatements[lStatementIndex].SafetyReason, lSnapshotPlan.FinalStatements[lStatementIndex].SafetyReason);
    Assert.AreEqual(lPlan.FinalStatements[lStatementIndex].ReplacementText, lSnapshotPlan.FinalStatements[lStatementIndex].ReplacementText);
  end;
end;
procedure ControlCase(const aShape: string);
var
  lHelper, lBody, lSource, lTarget: string;
  lTypeA, lTypeB, lHelperModel, lConsumer: TDelphiSemanticUnitModel;
begin
  lHelper := '  &THelp = record helper for %s'#13#10 +
    '    function Count: Integer;'#13#10'  end;'#13#10;
  lBody := 'procedure Run;'#13#10'var'#13#10'  lRecord: %s;'#13#10'  Count: Integer;'#13#10 +
    'begin'#13#10'  with lRecord do Count := 1;'#13#10'end;'#13#10;
  if MatchText(aShape, ['same-name', 'private-import', 'import', 'indexed-import']) then
  begin
    lTypeA := Unit_('TypesA', 'unit TypesA;'#13#10'interface'#13#10 +
      'type TRec = record Value: Integer; end;'#13#10'implementation'#13#10'end.');
    lTypeB := Unit_('TypesB', 'unit TypesB;'#13#10'interface'#13#10 +
      'type TRec = record Value: Integer; end;'#13#10'implementation'#13#10'end.');
    if aShape = 'private-import' then
      lSource := 'unit Helpers;'#13#10'interface'#13#10'implementation'#13#10 +
        'uses TypesA;'#13#10'type'#13#10
    else
      lSource := 'unit Helpers;'#13#10'interface'#13#10'uses TypesA;'#13#10'type'#13#10;
    if aShape = 'indexed-import' then
      lSource := lSource + '  THelp = record helper for TypesA.TRec'#13#10 +
        '    function Count: Integer;'#13#10'  end;'#13#10
    else
      lSource := lSource + Format(lHelper, ['TypesA.TRec']);
    if aShape <> 'private-import' then
      lSource := lSource + 'implementation'#13#10;
    lHelperModel := Unit_('Helpers', lSource + 'function ' +
      IfThen(aShape = 'indexed-import', '', '&') +
      'THelp.Count: Integer;'#13#10'begin Result := 1; end;'#13#10'end.');
    lTarget := 'TypesA.TRec';
    if aShape = 'same-name' then
      lTarget := 'TypesB.TRec';
    lConsumer := Unit_('Consumer', 'unit Consumer;'#13#10'interface'#13#10 +
      'uses TypesA, TypesB, Helpers;'#13#10'implementation'#13#10 +
      Format(lBody, [lTarget]) + 'end.');
    Report(aShape, [lConsumer, lTypeA, lTypeB, lHelperModel]);
  end else begin
    lSource := 'unit Consumer;'#13#10'interface'#13#10'type'#13#10 +
      '  TRec = record Value: Integer; end;'#13#10 +
      '  TOther = record Value: Integer; end;'#13#10;
    lTarget := 'TRec';
    if aShape = 'unrelated' then
      lTarget := 'TOther';
    if not MatchText(aShape, ['after-site', 'no-helper']) then
      lSource := lSource + Format(lHelper, [lTarget]);
    lSource := lSource + 'implementation'#13#10;
    if aShape = 'call' then
      lSource := lSource + 'procedure Count;'#13#10'begin'#13#10'end;'#13#10 +
        'procedure Run;'#13#10'var'#13#10'  lRecord: TRec;'#13#10'begin'#13#10 +
        '  with lRecord do Count();'#13#10'end;'#13#10
    else if MatchText(aShape, ['intrinsic', 'no-helper']) then
      lSource := lSource + 'procedure Run;'#13#10'var'#13#10'  lRecord: TRec;'#13#10 +
        '  lSize: Integer;'#13#10'begin'#13#10 +
        '  with lRecord do begin FillChar(Value, SizeOf(Value), 0); lSize := SizeOf(TRec); end;'#13#10 +
        'end;'#13#10
    else if aShape = 'local-array' then
      lSource := lSource + 'procedure Run;'#13#10'var'#13#10'  lRecord: TRec;'#13#10 +
        '  lArr: array[0..1] of Integer;'#13#10'begin'#13#10 +
        '  with lRecord do lArr[0] := Value;'#13#10 +
        'end;'#13#10
    else
      lSource := lSource + Format(lBody, ['TRec']);
    if aShape = 'after-site' then
      lSource := lSource + 'type'#13#10 + Format(lHelper, [lTarget]);
    lConsumer := Unit_('Consumer', lSource + IfThen(aShape = 'no-helper', '',
      'function &THelp.Count: Integer;'#13#10'begin Result := 1; end;'#13#10) + 'end.');
    Report(aShape, [lConsumer]);
  end;
end;


procedure ExtraCase(const aShape: string);
var
  lSource: string;
begin
  lSource := 'unit Consumer;'#13#10'interface'#13#10'type'#13#10 +
    '  TRec = record Value: Integer; end;'#13#10 +
    '  TAlias = TRec;'#13#10;
  if aShape = 'alias-receiver' then
    lSource := lSource + '  &THelp = record helper for TRec'#13#10'    function Count: Integer;'#13#10'  end;'#13#10
  else if aShape = 'alias-target' then
    lSource := lSource + '  &THelp = record helper for TAlias'#13#10'    function Count: Integer;'#13#10'  end;'#13#10
  else if aShape = 'class-helper' then
    lSource := lSource + '  &THelp = class helper for TObject'#13#10'    function Count: Integer;'#13#10'  end;'#13#10
  else
    lSource := lSource + '  &THelp = record helper for TRec'#13#10'    function Count: Integer;'#13#10'  end;'#13#10;
  lSource := lSource + 'implementation'#13#10;
  if aShape = 'alias-receiver' then
    lSource := lSource + 'procedure Run;'#13#10'var'#13#10'  lRecord: TAlias;'#13#10'  Count: Integer;'#13#10 +
      'begin'#13#10'  with lRecord do Count := 1;'#13#10'end;'#13#10
  else if aShape = 'local-alias' then
    lSource := lSource + 'procedure Run;'#13#10'type'#13#10'  TLocal = TRec;'#13#10'var'#13#10 +
      '  lRecord: TLocal;'#13#10'  Count: Integer;'#13#10 +
      'begin'#13#10'  with lRecord do Count := 1;'#13#10'end;'#13#10
  else if aShape = 'nested' then
    lSource := lSource + 'type'#13#10'  TOuter = record Inner: TRec; Other: Integer; end;'#13#10 +
      'procedure Run;'#13#10'var'#13#10'  lOuter: TOuter;'#13#10'  Count: Integer;'#13#10 +
      'begin'#13#10'  with lOuter do with Inner do Count := Other;'#13#10'end;'#13#10
  else
    lSource := lSource + 'procedure Run;'#13#10'var'#13#10'  lRecord: TRec;'#13#10'  Count: Integer;'#13#10 +
      'begin'#13#10'  with lRecord do Count := 1;'#13#10'end;'#13#10;
  Report('extra-' + aShape, [Unit_('Consumer', lSource +
    'function &THelp.Count: Integer;'#13#10'begin Result := 1; end;'#13#10'end.')]);
end;
begin
  lRoot := WithBinderTempPath('DS720-' + aShape);
  TDirectory.CreateDirectory(lRoot);
  if MatchText(aShape, ['alias-receiver', 'alias-target', 'local-alias', 'nested', 'class-helper']) then
  begin
    ExtraCase(aShape);
  end else begin
    ControlCase(aShape);
  end;
end;

procedure TWithBinderTests.UnindexedRecordHelperShieldsLexicalHomonym(const aShape: string);
var
  lDiagnostic: TDelphiSemanticModelDiagnostic;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lModel: TDelphiSemanticUnitModel;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lOptions: TDelphiSemanticModelOptions;
  lReference: TDelphiSemanticBoundReference;
  lSelector: string;
  lFound: Boolean;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := WithBinderTempPath('RecordHelper-' + aShape + '.pas');
  lSelector := 'lRecord';
  if aShape = 'indexed' then
    lSelector := 'lItems[0]'
  else if aShape = 'pointer' then
    lSelector := 'lPointer^';
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit RecordHelper;'#13#10'interface'#13#10 +
    IfThen(aShape = 'import', 'uses MissingHelperUnit;'#13#10, '') + 'type'#13#10 +
    '  TRec = record Value: Integer; end;'#13#10'  PRec = ^TRec;'#13#10 +
    '  &TRecHelper = record helper for TRec'#13#10 +
    '    function Count: Integer;'#13#10'  end;'#13#10 +
    'var Count: Integer;'#13#10'implementation'#13#10 +
    'function &TRecHelper.Count: Integer;'#13#10'begin Result := 1; end;'#13#10 +
    'procedure Run;'#13#10 +
    'var'#13#10'  lRecord: TRec;'#13#10'  lItems: array[0..0] of TRec;'#13#10 +
    '  lPointer: PRec;'#13#10'  Count: Integer;'#13#10 +
    'begin'#13#10'  with ' + lSelector + ' do Count := 1;'#13#10 +
    'end;'#13#10'end.', TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  lFound := False;
  for lDiagnostic in lModel.Diagnostics do
    if lDiagnostic.Code = 'AST_HELPER_DECLARATION_UNINDEXED' then
      lFound := True;
  Assert.IsTrue(lFound, 'The regression requires a real unindexed record helper.');
  lFacts := TDelphiSemanticWithBinder.BindProject('record-helper-' + aShape, nil, [lModel]);
  Assert.AreEqual(1, Integer(Length(lFacts.Bindings)));
  Assert.AreEqual('resolved', lFacts.Bindings[0].Selectors[0].Status);
  Assert.AreEqual('unit', lFacts.Bindings[0].Selectors[0].TypeIdentity.ScopeKind);
  TFile.WriteAllText(WithBinderTempPath('record-helper-model-' + aShape + '.json'),
    ModelToJson(lModel), TEncoding.UTF8);
  lFound := False;
  for lReference in lFacts.Bindings[0].References do
    if SameText(lReference.Name, 'Count') then
    begin
      lFound := True;
      Assert.AreEqual('unsupported', lReference.Classification);
      Assert.AreEqual('RECORD_HELPER_MEMBERS_UNVERIFIED', lReference.ReasonCode);
    end;
  Assert.IsTrue(lFound);
  if aShape = 'record' then
  begin
    lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
    Assert.AreEqual(1, Integer(Length(lPlan.FinalStatements)));
    Assert.AreEqual('skipped', lPlan.FinalStatements[0].Status,
      'An unindexed helper refusal must not bind the lexical Count in final planning.');
    Assert.AreEqual('receiver-member-not-found', lPlan.FinalStatements[0].Reason);
    Assert.AreEqual(0, Integer(Length(lPlan.FinalStatements[0].Edits)));
  end;
end;

procedure TWithBinderTests.RootAbsenceProviderFailureKeepsBindingUnsupported(const aMode: string);
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lProvider: IDelphiSemanticImplicitRootMemberAbsence;
  lReference: TDelphiSemanticBoundReference;
  lFound: Boolean;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := WithBinderTempPath('ProviderFailure-' + aMode + '.pas');
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit ProviderFailure;'#13#10'interface'#13#10 +
    'type TChild = class end;'#13#10'var lChild: TChild; lPair: Integer;'#13#10 +
    'implementation'#13#10'procedure Run;'#13#10'begin'#13#10 +
    '  with lChild do lPair := 1;'#13#10'end;'#13#10'end.', TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  lProvider := TThrowingRootAbsenceProvider.Create(aMode);
  try
    lFacts := TDelphiSemanticWithBinder.BindProject('provider-failure-' + aMode,
      nil, [lModel], lProvider);
  except
    on E: Exception do
      Assert.Fail('A failing provider aborted binding: ' + E.Message);
  end;
  Assert.AreEqual(1, Integer(Length(lFacts.Bindings)));
  lFound := False;
  for lReference in lFacts.Bindings[0].References do
    if SameText(lReference.Name, 'lPair') then
    begin
      lFound := True;
      Assert.AreEqual('unsupported', lReference.Classification);
      Assert.AreEqual('OWNER_INHERITED_MEMBERS_UNVERIFIED', lReference.ReasonCode);
    end;
  Assert.IsTrue(lFound);
end;

procedure TWithBinderTests.LocalLineageNeverBorrowsUnitTypeIdentity(const aShape: string);
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lReference: TDelphiSemanticBoundReference;
  lSelector: string;
  lFound: Boolean;
begin
  lSelector := 'lItems[0]';
  if aShape = 'pointer' then
    lSelector := 'lPointer^';
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := WithBinderTempPath('LocalLineage-' + aShape + '.pas');
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit LocalLineage;'#13#10'interface'#13#10 +
    'type TBase = class OtherValue: Integer; end;'#13#10 +
    '  TChild = class(TBase) end;'#13#10 +
    'var LeftOnly: Integer;'#13#10'implementation'#13#10'procedure Execute;'#13#10 +
    'type TBase = class LeftOnly: Integer; end;'#13#10 +
    '  TChild = class(TBase) end;'#13#10'  PChild = ^TChild;'#13#10 +
    'var lItems: array[0..0] of TChild; lPointer: PChild;'#13#10'begin'#13#10 +
    '  with ' + lSelector + ' do LeftOnly := 1;'#13#10'end;'#13#10'end.', TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  lFacts := TDelphiSemanticWithBinder.BindProject('local-lineage-' + aShape,
    nil, [lModel], TImplicitRootAbsenceStub.Create);
  Assert.AreEqual(1, Integer(Length(lFacts.Bindings)));
  lFound := False;
  for lReference in lFacts.Bindings[0].References do
    if SameText(lReference.Name, 'LeftOnly') then
    begin
      lFound := True;
      Assert.AreNotEqual('lexical', lReference.Classification,
        'A unit-level namesake cannot prove absence on the local base class.');
      Assert.AreNotEqual('unresolved', lReference.Classification);
    end;
  Assert.IsTrue(lFound);
end;

procedure TWithBinderTests.RootAbsenceNeverOverridesIndexedLineage(const aShape: string);
var
  lBinding: TDelphiSemanticWithBinding;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lProvider: IDelphiSemanticImplicitRootMemberAbsence;
  lReference: TDelphiSemanticBoundReference;
  lSelector: string;
  lText: string;
  lFound: Boolean;
begin
  lText := 'unit RootLineage;'#13#10'interface'#13#10'type'#13#10;
  if aShape = 'overload' then
    lText := lText + '  TBase = class'#13#10'  public'#13#10 +
      '    procedure LeftOnly(aValue: string); overload;'#13#10 +
      '    procedure LeftOnly(aValue: Integer); overload;'#13#10'  end;'#13#10
  else
    lText := lText + '  TBase = class LeftOnly: Integer; end;'#13#10;
  lText := lText + '  TChild = class(TBase)'#13#10'  end;'#13#10 +
    '  PChild = ^TChild;'#13#10;
  if aShape = 'overload' then
    lText := lText + 'procedure LeftOnly;'#13#10
  else
    lText := lText + 'var LeftOnly: Integer;'#13#10;
  lText := lText + 'implementation'#13#10;
  if aShape = 'overload' then
    lText := lText + 'procedure TBase.LeftOnly(aValue: string);'#13#10'begin'#13#10'end;'#13#10 +
      'procedure TBase.LeftOnly(aValue: Integer);'#13#10'begin'#13#10'end;'#13#10 +
      'procedure LeftOnly;'#13#10'begin'#13#10'end;'#13#10;
  lText := lText + 'procedure Execute;'#13#10 +
    'var lChild: TChild; lItems: array[0..0] of TChild; lPointer: PChild;'#13#10 +
    'begin'#13#10;
  lSelector := 'lChild';
  if aShape = 'indexed' then
    lSelector := 'lItems[0]'
  else if aShape = 'pointer' then
    lSelector := 'lPointer^';
  if aShape = 'overload' then
    lText := lText + '  with ' + lSelector + ' do LeftOnly;'#13#10
  else
    lText := lText + '  with ' + lSelector + ' do LeftOnly := 1;'#13#10;
  lText := lText + 'end;'#13#10'end.'#13#10;
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := WithBinderTempPath('RootLineage-' + aShape + '.pas');
  TFile.WriteAllText(lOptions.SourceFileName, lText, TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  lProvider := TImplicitRootAbsenceStub.Create;
  lFacts := TDelphiSemanticWithBinder.BindProject('root-lineage-' + aShape,
    nil, [lModel], lProvider);
  Assert.AreEqual(1, Integer(Length(lFacts.Bindings)));
  lBinding := lFacts.Bindings[0];
  lFound := False;
  for lReference in lBinding.References do
    if SameText(lReference.Name, 'LeftOnly') then
    begin
      lFound := True;
      Assert.AreEqual('unsupported', lReference.Classification,
        'Indexed lineage evidence must shield the lexical homonym.');
      if aShape = 'pointer' then
        Assert.AreEqual('SELECTOR_MEMBERS_UNVERIFIED', lReference.ReasonCode)
      else
      Assert.AreEqual('OWNER_INHERITED_MEMBERS_UNVERIFIED', lReference.ReasonCode);
    end;
  Assert.IsTrue(lFound);
end;

procedure TWithBinderTests.CompilerRoutineInWithBodyUsesIntrinsicFallback(const aName: string);
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := WithBinderTempPath('CompilerRoutine' + aName + '.pas');
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit CompilerRoutine' + aName + ';' + sLineBreak +
    'interface' + sLineBreak +
    'type TReceiver = record Value: Integer; end;' + sLineBreak +
    'var Receiver: TReceiver;' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure Run;' + sLineBreak +
    'begin' + sLineBreak +
    '  with Receiver do Value := ' + aName + '(Value);' + sLineBreak +
    'end;' + sLineBreak + 'end.', TEncoding.UTF8);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  Assert.AreEqual(1, Integer(Length(lBindings)));
  Assert.IsTrue(HasReference(lBindings[0], 'Value', 'member'));
  Assert.IsTrue(HasReference(lBindings[0], aName, 'intrinsic'), aName);
  Assert.AreEqual('planned', lBindings[0].Status);
end;

procedure TWithBinderTests.ConditionalWithBodyOnlyBindsActiveReferences(const aActive: Boolean);
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lReference: TDelphiSemanticBoundReference;
  lValueCount: Integer;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := WithBinderTempPath('ConditionalWith' + BoolToStr(aActive, True) + '.pas');
  if aActive then
    lOptions.Defines := ['ENABLE_MISSING'];
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit ConditionalWith;' + sLineBreak +
    'interface' + sLineBreak +
    'type TReceiver = record Value: Integer; end;' + sLineBreak +
    'var Receiver: TReceiver;' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure Run;' + sLineBreak +
    'begin' + sLineBreak +
    '  with Receiver do' + sLineBreak +
    '  begin' + sLineBreak +
    '    Value := 1;' + sLineBreak +
    '    {$IFDEF ENABLE_MISSING}' + sLineBreak +
    '    MissingName := 2;' + sLineBreak +
    '    {$ENDIF}' + sLineBreak +
    '    Value := 3;' + sLineBreak +
    '  end;' + sLineBreak +
    'end;' + sLineBreak + 'end.', TEncoding.UTF8);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(TFile.ReadAllText(lOptions.SourceFileName, TEncoding.UTF8), lModel.SourceText,
    'The original source remains available for rendering and byte verification.');
  lModel := JsonToModel(ModelToJson(lModel));
  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  Assert.AreEqual(1, Integer(Length(lBindings)));
  Assert.IsTrue(HasReference(lBindings[0], 'Value', 'member'));
  lValueCount := 0;
  for lReference in lBindings[0].References do
    if SameText(lReference.Name, 'Value') and SameText(lReference.Classification, 'member') then
    begin
      if lValueCount = 0 then
        Assert.AreEqual(10, lReference.Line)
      else
        Assert.AreEqual(14, lReference.Line);
      Assert.AreEqual(5, lReference.Column);
      Inc(lValueCount);
    end;
  Assert.AreEqual(2, lValueCount, 'Active references keep their original physical coordinates.');
  if aActive then
  begin
    Assert.IsTrue(HasReference(lBindings[0], 'MissingName', 'unresolved'));
    Assert.AreEqual('skipped', lBindings[0].Status);
  end else begin
    Assert.IsFalse(HasAnyReference(lBindings[0], 'MissingName'),
      'Inactive source must not regain references during coordinate reconciliation.');
    // Round 23: the public refusal retains the base reason; inactive detail is separate.
    Assert.AreEqual('skipped', lBindings[0].Status);
    Assert.AreEqual('UNRESOLVED_REFERENCE', lBindings[0].SkipReason);
    Assert.AreEqual('UNRESOLVED_REFERENCE', lBindings[0].InactiveSpanSkipReason);
  end;
end;

procedure TWithBinderTests.QualifiedPointerFieldNeverBindsToWithHomonym(const aShape: string);
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lExpression: string;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lExpression := 'p^.n';
  if SameText(aShape, 'homonym') then
    lExpression := lExpression + ' + n'
  else if SameText(aShape, 'range') then
    lExpression := lExpression + '; if Value in [1..n] then Value := 1'
  else if SameText(aShape, 'unknown') then
    lExpression := 'MissingPointer^.n';
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := WithBinderTempPath('QualifiedPointer' + aShape + '.pas');
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit QualifiedPointer' + aShape + ';' + sLineBreak +
    'interface' + sLineBreak +
    'type TNode = record n: Integer; end;' + sLineBreak +
    '  TReceiver = record Value, n: Integer; end;' + sLineBreak +
    'var Receiver: TReceiver;' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure Run;' + sLineBreak +
    'var p: ^TNode;' + sLineBreak +
    'begin' + sLineBreak +
    '  with Receiver do' + sLineBreak +
    '  begin' + sLineBreak +
    '    Value := ' + lExpression + ';' + sLineBreak +
    '  end;' + sLineBreak +
    'end;' + sLineBreak + 'end.', TEncoding.UTF8);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  Assert.AreEqual(1, Integer(Length(lBindings)));
  Assert.IsTrue(HasReference(lBindings[0], 'Value', 'member'));
  if SameText(aShape, 'homonym') or SameText(aShape, 'range') then
  begin
    Assert.AreEqual(1, CountReferences(lBindings[0], 'n'),
      'Only the bare n may bind to the WITH receiver.');
    Assert.IsTrue(HasReference(lBindings[0], 'n', 'member'));
  end else
    Assert.IsFalse(HasAnyReference(lBindings[0], 'n'),
      'The explicitly qualified field must retain its own receiver.');
  if SameText(aShape, 'unknown') then
  begin
    Assert.IsTrue(HasReference(lBindings[0], 'MissingPointer', 'unresolved'));
    Assert.AreEqual('skipped', lBindings[0].Status);
  end else begin
    Assert.IsTrue(HasReference(lBindings[0], 'p', 'lexical'));
    Assert.AreEqual('planned', lBindings[0].Status);
  end;
end;

procedure TWithBinderTests.IntrinsicFallbackPreservesNamePrecedenceAndUnknownRefusal(
  const aShape: string);
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lMemberText: string;
  lModel: TDelphiSemanticUnitModel;
  lName: string;
  lOptions: TDelphiSemanticModelOptions;
  lVariableText: string;
begin
  lMemberText := '';
  lVariableText := '';
  lName := 'SizeOf';
  if SameText(aShape, 'member') then
    lMemberText := ' SizeOf: Integer;'
  else if SameText(aShape, 'lexical') then
    lVariableText := 'var SizeOf: Integer;' + sLineBreak
  else
    lName := 'MissingCompilerRoutine';
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := WithBinderTempPath('IntrinsicPrecedence' + aShape + '.pas');
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit IntrinsicPrecedence' + aShape + ';' + sLineBreak +
    'interface' + sLineBreak +
    'type TReceiver = record Value: Integer;' + lMemberText + ' end;' + sLineBreak +
    'var Receiver: TReceiver;' + sLineBreak + lVariableText +
    'implementation' + sLineBreak +
    'procedure Run;' + sLineBreak +
    'begin' + sLineBreak +
    '  with Receiver do Value := ' + lName + ';' + sLineBreak +
    'end;' + sLineBreak + 'end.', TEncoding.UTF8);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  Assert.AreEqual(1, Integer(Length(lBindings)));
  Assert.IsFalse(HasReference(lBindings[0], lName, 'intrinsic'));
  if SameText(aShape, 'unknown') then
  begin
    Assert.IsTrue(HasReference(lBindings[0], lName, 'unresolved'));
    Assert.AreEqual('NAME_NOT_FOUND', ReasonOf(lBindings[0], lName, 'unresolved'));
    Assert.AreEqual('skipped', lBindings[0].Status);
  end else begin
    Assert.IsTrue(HasReference(lBindings[0], lName, aShape));
    Assert.AreEqual('planned', lBindings[0].Status);
  end;
end;

procedure TWithBinderTests.NestedLocalReceiverKeepsSourceScopeAndIdentity;
var
  lBinding: TDelphiSemanticWithBinding;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticApiOptions;
  lSeenNested: Boolean;
begin
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := FixturePath('RemoveWithLocalCaptureType',
    'LocalReceiver.dproj');
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(
    lOptions);
  lSeenNested := False;
  for lBinding in lFacts.Bindings do
    if SameText(ExtractFileName(lBinding.FileName), 'LocalConsumer.pas') and
      (lBinding.Line = 37) then
    begin
      lSeenNested := True;
      Assert.IsNotEmpty(lBinding.RoutineScopeId);
      Assert.AreEqual(1, Integer(Length(lBinding.Selectors)));
      Assert.AreEqual('resolved', lBinding.Selectors[0].Status);
      Assert.AreEqual('TOuter', lBinding.Selectors[0].TypeIdentity.Name);
      Assert.AreEqual('routine', lBinding.Selectors[0].TypeIdentity.ScopeKind);
      Assert.IsNotEmpty(lBinding.Selectors[0].TypeIdentity.OwnerScopeId);
      Assert.IsNotEmpty(lBinding.Selectors[0].TypeIdentity.SemanticSymbolId);
      Assert.AreNotEqual(lBinding.RoutineScopeId,
        lBinding.Selectors[0].TypeIdentity.OwnerScopeId,
        'The receiver type belongs to the enclosing routine.');
    end;
  Assert.IsTrue(lSeenNested, 'The source-backed nested WITH must be discovered.');
end;

procedure TWithBinderTests.LocalPointerPointeeShadowsImportedUnitHomonym;
var
  lBinding: TDelphiSemanticWithBinding;
  lConsumerModel: TDelphiSemanticUnitModel;
  lDeclaration: TDelphiSemanticDeclaration;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lGuid: TGUID;
  lGuidText: string;
  lLocal: TDelphiSemanticLocal;
  lLocalType: TDelphiSemanticDeclaration;
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticApiOptions;
  lProjectPath: string;
  lProviderTypeCount: Integer;
  lRoot: string;
  lSeenBinding: Boolean;
  lSeenConsumer: Boolean;
  lSeenLocalMember: Boolean;
  lSeenLocalType: Boolean;
  lSeenPointer: Boolean;
  lSeenProvider: Boolean;
  lSeenProviderUse: Boolean;
  lSeenSymbol: Boolean;
  lSymbol: TDelphiSemanticInventorySymbol;
  lUsedUnit: string;
begin
  CreateGUID(lGuid);
  lGuidText := StringReplace(StringReplace(GUIDToString(lGuid), '{', '', [rfReplaceAll]),
    '}', '', [rfReplaceAll]);
  lRoot := WithBinderTempPath('local-pointer-homonym-' + lGuidText);
  TDirectory.CreateDirectory(lRoot);
  lProjectPath := TPath.Combine(lRoot, 'PointerScopeHomonym.dproj');
  TFile.WriteAllText(TPath.Combine(lRoot, 'PointerScopeHomonym.dpr'),
    'program PointerScopeHomonym;'#13#10 +
    'uses LocalPointerConsumer in ''LocalPointerConsumer.pas'';'#13#10 +
    'begin'#13#10'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(lProjectPath,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>PointerScopeHomonym.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="LocalPointerProvider.pas"/>' +
    '<DCCReference Include="LocalPointerConsumer.pas"/></ItemGroup></Project>',
    TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'LocalPointerProvider.pas'),
    'unit LocalPointerProvider;'#13#10 +
    'interface'#13#10 +
    'type TNode = record UnitOnly: Integer; end;'#13#10 +
    'implementation'#13#10'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'LocalPointerConsumer.pas'),
    'unit LocalPointerConsumer;'#13#10 +
    'interface'#13#10 +
    'procedure Run;'#13#10 +
    'implementation'#13#10 +
    'uses LocalPointerProvider;'#13#10 +
    'procedure Run;'#13#10 +
    'type TNode = record LocalOnly: Integer; end;'#13#10 +
    'var'#13#10 +
    '  lNode: TNode;'#13#10 +
    '  lPointer: ^TNode;'#13#10 +
    '  procedure Nested;'#13#10 +
    '  begin'#13#10 +
    '    with lPointer^ do LocalOnly := 1;'#13#10 +
    '  end;'#13#10 +
    'begin'#13#10 +
    '  lPointer := @lNode;'#13#10 +
    '  Nested;'#13#10 +
    'end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := lProjectPath;
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  lConsumerModel := Default(TDelphiSemanticUnitModel);
  lSeenConsumer := False;
  lSeenProvider := False;
  lSeenProviderUse := False;
  lProviderTypeCount := 0;
  for lModel in lFacts.UnitModels do
  begin
    if SameText(lModel.UnitName, 'LocalPointerConsumer') then
    begin
      lConsumerModel := lModel;
      lSeenConsumer := True;
      for lUsedUnit in lModel.ImplementationUses do
        if SameText(lUsedUnit, 'LocalPointerProvider') then
          lSeenProviderUse := True;
    end else if SameText(lModel.UnitName, 'LocalPointerProvider') then
    begin
      lSeenProvider := True;
      for lDeclaration in lModel.Declarations do
        if SameText(lDeclaration.Name, 'TNode') and
          SameText(lDeclaration.ScopeKind, 'unit') then
          Inc(lProviderTypeCount);
    end;
  end;
  Assert.IsTrue(lSeenConsumer and lConsumerModel.Success, 'Actual consumer AST model');
  Assert.IsTrue(lSeenProvider and lSeenProviderUse and (lProviderTypeCount = 1),
    'The imported unit homonym must be present and visible to the consumer.');
  lLocalType := Default(TDelphiSemanticDeclaration);
  lSeenLocalType := False;
  for lDeclaration in lConsumerModel.Declarations do
    if SameText(lDeclaration.Name, 'TNode') and
      SameText(lDeclaration.ScopeKind, 'routine') then
    begin
      Assert.IsFalse(lSeenLocalType, 'Only one local TNode should be declared.');
      lLocalType := lDeclaration;
      lSeenLocalType := True;
    end;
  Assert.IsTrue(lSeenLocalType, 'The actual AST must retain the local declaration.');
  Assert.IsNotEmpty(lLocalType.OwnerScopeId);
  Assert.IsNotEmpty(lLocalType.SymbolId);
  lSeenPointer := False;
  for lLocal in lConsumerModel.Locals do
    if SameText(lLocal.Name, 'lPointer') then
    begin
      Assert.IsFalse(lSeenPointer, 'Only one pointer local should be extracted.');
      Assert.AreEqual('Run', lLocal.RoutineName);
      Assert.AreEqual('^TNode', lLocal.TypeName);
      Assert.AreEqual(lLocalType.OwnerScopeId, lLocal.RoutineScopeId);
      Assert.IsTrue(lLocal.Line > 0, 'The pointer local needs a source position.');
      lSeenPointer := True;
    end;
  Assert.IsTrue(lSeenPointer, 'The actual model must extract the pointer local.');
  lSeenLocalMember := False;
  for lMember in lConsumerModel.Members do
    if SameText(lMember.Name, 'LocalOnly') then
    begin
      Assert.AreEqual(lLocalType.OwnerScopeId, lMember.OwnerScopeId);
      Assert.AreEqual(lLocalType.SymbolId, lMember.OwnerSymbolId);
      lSeenLocalMember := True;
    end;
  Assert.IsTrue(lSeenLocalMember, 'The local member must retain its AST owner.');
  lSeenBinding := False;
  for lBinding in lFacts.Bindings do
    if SameText(lBinding.UnitName, 'LocalPointerConsumer') and
      SameText(lBinding.RoutineName, 'Nested') and
      SameText(lBinding.SelectorText, 'lPointer^') then
    begin
      Assert.IsFalse(lSeenBinding, 'Only one nested pointer WITH should be bound.');
      lSeenBinding := True;
      Assert.AreEqual(1, Integer(Length(lBinding.Selectors)));
      Assert.AreEqual('resolved', lBinding.Selectors[0].Status,
        lBinding.Selectors[0].ReasonCode);
      Assert.AreEqual('LocalPointerConsumer',
        lBinding.Selectors[0].TypeIdentity.UnitName);
      Assert.AreEqual('routine', lBinding.Selectors[0].TypeIdentity.ScopeKind);
      Assert.AreEqual(lLocalType.OwnerScopeId,
        lBinding.Selectors[0].TypeIdentity.OwnerScopeId);
      Assert.AreEqual(lLocalType.SymbolId,
        lBinding.Selectors[0].TypeIdentity.SemanticSymbolId);
      Assert.AreEqual(TPath.Combine(lRoot, 'LocalPointerConsumer.pas'),
        lBinding.Selectors[0].TypeIdentity.SourceRange.FileName);
      Assert.AreEqual('TNode', ReceiverOf(lBinding, 'LocalOnly', 'member'));
      Assert.IsFalse(HasReference(lBinding, 'UnitOnly', 'member'));
    end;
  Assert.IsTrue(lSeenBinding, 'The source-backed nested pointer WITH must be found.');
  lSeenSymbol := False;
  for lSymbol in lFacts.Symbols do
    if SameText(lSymbol.UnitName, 'LocalPointerConsumer') and
      SameText(lSymbol.Name, 'LocalOnly') and
      SameText(lSymbol.SymbolClass, 'field') then
    begin
      Assert.AreEqual(lLocalType.OwnerScopeId, lSymbol.OwnerIdentity.OwnerScopeId);
      Assert.AreEqual(lLocalType.SymbolId, lSymbol.OwnerIdentity.SemanticSymbolId);
      lSeenSymbol := True;
    end;
  Assert.IsTrue(lSeenSymbol, 'The receiver member must use the local owner identity.');
end;

function BuildPointerAliasScopeModel: TDelphiSemanticUnitModel;
var
  lGuid: TGUID;
  lGuidText: string;
  lOptions: TDelphiSemanticModelOptions;
  lRoot: string;
begin
  CreateGUID(lGuid);
  lGuidText := StringReplace(StringReplace(GUIDToString(lGuid), '{', '', [rfReplaceAll]),
    '}', '', [rfReplaceAll]);
  lRoot := WithBinderTempPath('pointer-alias-scope-' + lGuidText);
  TDirectory.CreateDirectory(lRoot);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'PointerAliasScope.pas');
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit PointerAliasScope;'#13#10 +
    'interface'#13#10 +
    'type'#13#10 +
    '  TNode = record UnitOnly: Integer; end;'#13#10 +
    '  PUnitNode = ^TNode;'#13#10 +
    'procedure UnitAliasRun(aItem: PUnitNode);'#13#10 +
    'procedure LocalAliasRun;'#13#10 +
    'implementation'#13#10 +
    'procedure UnitAliasRun(aItem: PUnitNode);'#13#10 +
    'type TNode = record LocalOnly: Integer; end;'#13#10 +
    'begin'#13#10 +
    '  with aItem^ do UnitOnly := 1;'#13#10 +
    'end;'#13#10 +
    'procedure LocalAliasRun;'#13#10 +
    'type'#13#10 +
    '  TNode = record LocalOnly: Integer; end;'#13#10 +
    '  PLocalNode = ^TNode;'#13#10 +
    'var'#13#10 +
    '  lItem: PLocalNode;'#13#10 +
    'begin'#13#10 +
    '  with lItem^ do LocalOnly := 1;'#13#10 +
    'end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(Result.Success, 'The pointer alias fixture must extract from source.');
end;

procedure TWithBinderTests.PointerAliasesResolvePointeesFromTheirDeclarationScopes;
var
  lBinding: TDelphiSemanticWithBinding;
  lDeclaration: TDelphiSemanticDeclaration;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lLocalScopeId: string;
  lModel: TDelphiSemanticUnitModel;
  lRoutine: TDelphiSemanticRoutine;
  lSeenLocal: Boolean;
  lSeenUnit: Boolean;
  lUnitNodeId: string;
  lLocalNodeId: string;
begin
  lModel := BuildPointerAliasScopeModel;
  lUnitNodeId := '';
  lLocalNodeId := '';
  lLocalScopeId := '';
  for lRoutine in lModel.Routines do
    if SameText(lRoutine.Name, 'LocalAliasRun') and
      SameText(lRoutine.SectionKind, 'implementation') then
      lLocalScopeId := lRoutine.ScopeId;
  Assert.IsNotEmpty(lLocalScopeId);
  for lDeclaration in lModel.Declarations do
    if SameText(lDeclaration.Name, 'TNode') and
      SameText(lDeclaration.ScopeKind, 'unit') then
      lUnitNodeId := lDeclaration.SymbolId
    else if SameText(lDeclaration.Name, 'TNode') and
      SameText(lDeclaration.ScopeKind, 'routine') and
      SameText(lDeclaration.OwnerScopeId, lLocalScopeId) then
      lLocalNodeId := lDeclaration.SymbolId;
  Assert.IsNotEmpty(lUnitNodeId);
  Assert.IsNotEmpty(lLocalNodeId);
  lFacts := TDelphiSemanticWithBinder.BindProject('', nil, [lModel]);
  lSeenUnit := False;
  lSeenLocal := False;
  for lBinding in lFacts.Bindings do
  begin
    if SameText(lBinding.RoutineName, 'UnitAliasRun') then
    begin
      Assert.IsFalse(lSeenUnit);
      lSeenUnit := True;
      Assert.AreEqual(1, Integer(Length(lBinding.Selectors)));
      Assert.AreEqual('resolved', lBinding.Selectors[0].Status,
        lBinding.Selectors[0].ReasonCode);
      Assert.AreEqual('unit', lBinding.Selectors[0].TypeIdentity.ScopeKind);
      Assert.AreEqual(lUnitNodeId,
        lBinding.Selectors[0].TypeIdentity.SemanticSymbolId);
      Assert.AreEqual('TNode', ReceiverOf(lBinding, 'UnitOnly', 'member'));
      Assert.IsFalse(HasReference(lBinding, 'LocalOnly', 'member'));
    end else if SameText(lBinding.RoutineName, 'LocalAliasRun') then
    begin
      Assert.IsFalse(lSeenLocal);
      lSeenLocal := True;
      Assert.AreEqual(1, Integer(Length(lBinding.Selectors)));
      Assert.AreEqual('resolved', lBinding.Selectors[0].Status,
        lBinding.Selectors[0].ReasonCode);
      Assert.AreEqual('routine', lBinding.Selectors[0].TypeIdentity.ScopeKind);
      Assert.AreEqual(lLocalNodeId,
        lBinding.Selectors[0].TypeIdentity.SemanticSymbolId);
      Assert.AreEqual('TNode', ReceiverOf(lBinding, 'LocalOnly', 'member'));
      Assert.IsFalse(HasReference(lBinding, 'UnitOnly', 'member'));
    end;
  end;
  Assert.IsTrue(lSeenUnit and lSeenLocal, 'Both source-backed alias bindings are required.');
end;

procedure TWithBinderTests.RoutineLocalHomonymMembersUseTheirOwnDeclaration;
var
  lBinding: TDelphiSemanticWithBinding;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lGuid: TGUID;
  lGuidText: string;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lOwnName: string;
  lOtherName: string;
  lRoot: string;
  lSeenFirst: Boolean;
  lSeenSecond: Boolean;
begin
  // DS-685 C7: two routines each declare a local TNode, and the unit declares a
  // third TNode. Each WITH must bind only the members of its own local type.
  CreateGUID(lGuid);
  lGuidText := StringReplace(StringReplace(GUIDToString(lGuid), '{', '', [rfReplaceAll]),
    '}', '', [rfReplaceAll]);
  lRoot := WithBinderTempPath('local-homonym-members-' + lGuidText);
  TDirectory.CreateDirectory(lRoot);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'LocalHomonymMembers.pas');
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit LocalHomonymMembers;'#13#10 +
    'interface'#13#10 +
    'type'#13#10 +
    '  TNode = record UnitOnly: Integer; Shared: Integer; end;'#13#10 +
    'procedure RunFirst(aValue: Integer);'#13#10 +
    'procedure RunSecond(const aText: string);'#13#10 +
    'implementation'#13#10 +
    'procedure RunFirst(aValue: Integer);'#13#10 +
    'type'#13#10 +
    '  TNode = record FirstOnly: Integer; Shared: Integer; end;'#13#10 +
    'var'#13#10 +
    '  lItem: TNode;'#13#10 +
    'begin'#13#10 +
    '  with lItem do'#13#10 +
    '  begin'#13#10 +
    '    FirstOnly := aValue;'#13#10 +
    '    Shared := 1;'#13#10 +
    '    SecondOnly := 2;'#13#10 +
    '    UnitOnly := 3;'#13#10 +
    '  end;'#13#10 +
    'end;'#13#10 +
    'procedure RunSecond(const aText: string);'#13#10 +
    'type'#13#10 +
    '  TNode = record SecondOnly: Integer; Shared: Integer; end;'#13#10 +
    'var'#13#10 +
    '  lItem: TNode;'#13#10 +
    'begin'#13#10 +
    '  with lItem do'#13#10 +
    '  begin'#13#10 +
    '    SecondOnly := Length(aText);'#13#10 +
    '    Shared := 1;'#13#10 +
    '    FirstOnly := 2;'#13#10 +
    '    UnitOnly := 3;'#13#10 +
    '  end;'#13#10 +
    'end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success, 'The local homonym fixture must extract from source.');
  lFacts := TDelphiSemanticWithBinder.BindProject('', nil, [lModel]);
  lSeenFirst := False;
  lSeenSecond := False;
  for lBinding in lFacts.Bindings do
  begin
    Assert.AreEqual(1, Integer(Length(lBinding.Selectors)));
    Assert.AreEqual('resolved', lBinding.Selectors[0].Status, lBinding.Selectors[0].ReasonCode);
    Assert.AreEqual('routine', lBinding.Selectors[0].TypeIdentity.ScopeKind);
    if SameText(lBinding.RoutineName, 'RunFirst') then
    begin
      Assert.IsFalse(lSeenFirst);
      lSeenFirst := True;
      lOwnName := 'FirstOnly';
      lOtherName := 'SecondOnly';
    end else
    begin
      Assert.IsFalse(lSeenSecond);
      lSeenSecond := True;
      lOwnName := 'SecondOnly';
      lOtherName := 'FirstOnly';
    end;
    Assert.AreEqual('TNode', ReceiverOf(lBinding, lOwnName, 'member'),
      lOwnName + ' must bind to its own routine-local TNode: ' +
      ReasonOf(lBinding, lOwnName, 'ambiguous'));
    Assert.AreEqual('TNode', ReceiverOf(lBinding, 'Shared', 'member'),
      'Shared must bind to the routine-local TNode, not be ambiguous: ' +
      ReasonOf(lBinding, 'Shared', 'ambiguous'));
    Assert.IsFalse(HasReference(lBinding, lOtherName, 'member'),
      lOtherName + ' belongs to the other routine-local TNode.');
    Assert.IsFalse(HasReference(lBinding, 'UnitOnly', 'member'),
      'UnitOnly belongs to the unit-level TNode homonym.');
  end;
  Assert.IsTrue(lSeenFirst and lSeenSecond, 'Both routine-local bindings are required.');
end;

function RoutineLocalInheritedReferenceProblem(const aBinding: TDelphiSemanticWithBinding;
  const aName: string): string;
var
  lReference: TDelphiSemanticBoundReference;
begin
  // A member a routine-local class may inherit must be refused or bound to its
  // declaring ancestor; it may never bind to an outer receiver or stay lexical.
  Result := '';
  for lReference in aBinding.References do
    if SameText(lReference.Name, aName) and
      (not MatchText(lReference.Classification, ['unsupported', 'ambiguous'])) and
      (not (SameText(lReference.Classification, 'member') and
      SameText(lReference.ReceiverTypeName, 'TBase'))) then
      Result := Result + ' ' + aBinding.RoutineName + ':' + aName + '=' +
        lReference.Classification + '/' + lReference.ReceiverTypeName + '/' +
        lReference.ReasonCode;
end;

procedure TWithBinderTests.LocalAliasVisibilityUsesCallerUnitIdentity(
  const aVisibility: string);
var
  lBinding: TDelphiSemanticWithBinding;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lInspected: Integer;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lOptions: TDelphiSemanticModelOptions;
  lRoot: string;
begin
  // DS-701 review: two unrelated classes named TBase must not share access.
  lRoot := WithBinderTempPath('alias-visibility-' + StringReplace(aVisibility, ' ', '-',
    [rfReplaceAll]));
  TDirectory.CreateDirectory(lRoot);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := TPath.Combine(lRoot, 'AliasVisibilityA.pas');
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit AliasVisibilityA;'#13#10 +
    'interface'#13#10 +
    'type TBase = class'#13#10 +
    '  ' + aVisibility + ' Hidden: Integer;'#13#10 +
    '  public Visible: Integer; procedure Run;'#13#10 +
    'end;'#13#10 +
    'implementation'#13#10 +
    'procedure TBase.Run;'#13#10 +
    'type TOwnAlias = TBase;'#13#10 +
    'var lItem: TOwnAlias;'#13#10 +
    'begin with lItem do begin Hidden := 1; Visible := 1; end; end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  SetLength(lModels, 2);
  lModels[0] := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModels[0].Success);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'AliasVisibilityB.pas');
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit AliasVisibilityB;'#13#10 +
    'interface'#13#10 +
    'uses AliasVisibilityA;'#13#10 +
    'type TBase = class public Hidden: Integer; procedure Run; end;'#13#10 +
    'implementation'#13#10 +
    'procedure TBase.Run;'#13#10 +
    'type TAlias = AliasVisibilityA.TBase;'#13#10 +
    'var lItem: TAlias;'#13#10 +
    'begin with lItem do begin Hidden := 1; Visible := 1; end; end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  lModels[1] := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModels[1].Success);
  lFacts := TDelphiSemanticWithBinder.BindProject('', nil, lModels);
  lInspected := 0;
  for lBinding in lFacts.Bindings do
    if SameText(lBinding.SelectorText, 'lItem') then
    begin
      Inc(lInspected);
      Assert.AreEqual('resolved', lBinding.Selectors[0].Status);
      Assert.AreEqual('routine', lBinding.Selectors[0].TypeIdentity.ScopeKind);
      Assert.IsTrue(HasReference(lBinding, 'Visible', 'member'));
      Assert.AreEqual(1, CountReferences(lBinding, 'Hidden'));
      if SameText(lBinding.UnitName, 'AliasVisibilityB') then
      begin
        Assert.IsTrue(HasReference(lBinding, 'Hidden', 'unsupported'),
          'The unrelated caller TBase must not acquire another unit TBase access.');
        Assert.IsFalse(HasReference(lBinding, 'Hidden', 'member'));
        Assert.IsFalse(HasReference(lBinding, 'Hidden', 'lexical'));
      end else begin
        Assert.AreEqual('AliasVisibilityA', lBinding.UnitName);
        Assert.IsTrue(HasReference(lBinding, 'Hidden', 'member'),
          'A local alias in the actual declaring class retains its access.');
      end;
    end;
  Assert.AreEqual(2, lInspected);
end;

procedure TWithBinderTests.FinalizedLocalAliasesUseTargetMemberIdentities(
  const aTargetKind: string);
var
  lBinding: TDelphiSemanticWithBinding;
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lInspected: Integer;
  lLocalTypes: string;
  lLexicalTypes: string;
  lLexicalTargetId: string;
  lOuterTargetId: string;
  lReference: TDelphiSemanticBoundReference;
  lParentMembers: string;
  lVisibility: string;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lTargetName: string;
begin
  // DS-701: alias declaration IDs own no fields. Bind through the finalized
  // target identity; an inherited miss still cannot fall through unsafely.
  lTargetName := 'TSafe';
  if SameText(aTargetKind, 'LocalRecord') then
    lTargetName := 'TLocal'
  else if MatchText(aTargetKind, ['UnitClass', 'StrictPrivate']) then
    lTargetName := 'TBase'
  else if SameText(aTargetKind, 'Unknown') then
    lTargetName := 'TUnknown';
  lParentMembers := 'InheritedValue: Integer;';
  lVisibility := '';
  if SameText(aTargetKind, 'StrictPrivate') then
  begin
    lParentMembers := lParentMembers + ' Caption: Integer;';
    lVisibility := 'strict private ';
  end;
  lLocalTypes := 'type'#13#10;
  if SameText(aTargetKind, 'LocalRecord') then
    lLocalTypes := lLocalTypes +
      '  TLocal = record Caption: Integer; InheritedValue: Integer; end;'#13#10;
  lLocalTypes := lLocalTypes + '  TAlias = ' + lTargetName + ';'#13#10;
  lLexicalTypes := lLocalTypes;
  if SameText(aTargetKind, 'LocalRecord') then
    lLexicalTypes := StringReplace(lLocalTypes, 'Caption: Integer', 'Caption: Cardinal',
      [rfReplaceAll]);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := WithBinderTempPath('local-alias-' + aTargetKind + '.pas');
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit LocalAliasMemberIdentities;'#13#10 +
    'interface'#13#10 +
    'type'#13#10 +
    '  TParent = class ' + lParentMembers + ' end;'#13#10 +
    '  TBase = class(TParent) ' + lVisibility + 'Caption: Integer; end;'#13#10 +
    '  TSafe = record Caption: Integer; InheritedValue: Integer; end;'#13#10 +
    '  TOuter = record Caption: Integer; InheritedValue: Integer; Count: Integer; end;'#13#10 +
    'var Count: Integer;'#13#10 +
    'implementation'#13#10 +
    'procedure RunOuter;'#13#10 + lLocalTypes +
    'var'#13#10 +
    '  lItem: TAlias;'#13#10 +
    '  lOuter: TOuter;'#13#10 +
    'begin'#13#10 +
    '  with lOuter do with lItem do'#13#10 +
    '  begin Caption := 1; InheritedValue := 1; Count := 1; end;'#13#10 +
    'end;'#13#10 +
    'procedure RunLexical;'#13#10 + lLexicalTypes +
    'var lItem: TAlias;'#13#10 +
    'begin'#13#10 +
    '  with lItem do'#13#10 +
    '  begin Caption := 1; InheritedValue := 1; Count := 1; end;'#13#10 +
    'end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success, 'Alias source must extract before checking binding.');
  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  lInspected := 0;
  lLexicalTargetId := '';
  lOuterTargetId := '';
  for lBinding in lBindings do
    if SameText(lBinding.SelectorText, 'lItem') then
    begin
      Inc(lInspected);
      if SameText(aTargetKind, 'Unknown') then
      begin
        Assert.AreEqual('unsupported', lBinding.Selectors[High(lBinding.Selectors)].Status);
        Assert.AreEqual('ROUTINE_LOCAL_TYPE_UNSUPPORTED',
          lBinding.Selectors[High(lBinding.Selectors)].ReasonCode);
        Assert.IsTrue(HasReference(lBinding, 'Caption', 'unsupported'));
        Assert.IsTrue(HasReference(lBinding, 'Count', 'unsupported'));
      end else begin
        Assert.AreEqual('resolved', lBinding.Selectors[High(lBinding.Selectors)].Status);
        Assert.AreEqual('routine', lBinding.Selectors[High(lBinding.Selectors)].TypeIdentity.ScopeKind);
        Assert.AreEqual('type-alias', lBinding.Selectors[High(lBinding.Selectors)].TypeIdentity.Kind);
        Assert.IsNotEmpty(lBinding.Selectors[High(lBinding.Selectors)].TypeIdentity.CanonicalId.Value);
        if SameText(aTargetKind, 'StrictPrivate') then
        begin
          Assert.IsTrue(HasReference(lBinding, 'Caption', 'unsupported'),
            'An inaccessible direct member must shield a public ancestor homonym.');
          Assert.IsFalse(HasReference(lBinding, 'Caption', 'member'));
        end else begin
          Assert.IsTrue(HasReference(lBinding, 'Caption', 'member'),
            'The finalized alias must bind the target field, rather than the outer homonym.');
          Assert.AreEqual(lTargetName, ReceiverOf(lBinding, 'Caption', 'member'));
        end;
        if SameText(aTargetKind, 'LocalRecord') then
        begin
          if SameText(lBinding.RoutineName, 'RunOuter') then
            lOuterTargetId := lBinding.Selectors[High(lBinding.Selectors)].TypeIdentity.CanonicalId.Value
          else
            lLexicalTargetId := lBinding.Selectors[High(lBinding.Selectors)].TypeIdentity.CanonicalId.Value;
          for lReference in lBinding.References do
            if SameText(lReference.Name, 'Caption') then
              if SameText(lBinding.RoutineName, 'RunOuter') then
                Assert.AreEqual('Integer', lReference.TypeName)
              else
                Assert.AreEqual('Cardinal', lReference.TypeName,
                  'The other routine TLocal field has a different source-backed type.');
        end;
        Assert.IsTrue(HasReference(lBinding, 'InheritedValue', 'member'));
        if MatchText(aTargetKind, ['UnitClass', 'StrictPrivate']) then
        begin
          Assert.AreEqual('TParent', ReceiverOf(lBinding, 'InheritedValue', 'member'));
          Assert.IsTrue(HasReference(lBinding, 'Count', 'unsupported'));
          Assert.IsFalse(HasReference(lBinding, 'Count', 'member'));
          Assert.IsFalse(HasReference(lBinding, 'Count', 'lexical'));
        end else begin
          Assert.AreEqual(lTargetName, ReceiverOf(lBinding, 'InheritedValue', 'member'));
          if SameText(lBinding.RoutineName, 'RunOuter') then
            Assert.AreEqual('TOuter', ReceiverOf(lBinding, 'Count', 'member'))
          else
            Assert.IsTrue(HasReference(lBinding, 'Count', 'lexical'));
        end;
      end;
      Assert.AreEqual(1, CountReferences(lBinding, 'Caption'));
      Assert.AreEqual(1, CountReferences(lBinding, 'InheritedValue'));
      Assert.AreEqual(1, CountReferences(lBinding, 'Count'));
    end;
  Assert.AreEqual(2, lInspected, 'Inspect alias receiver inside outer WITH and directly.');
  if SameText(aTargetKind, 'LocalRecord') then
  begin
    Assert.IsNotEmpty(lOuterTargetId);
    Assert.IsNotEmpty(lLexicalTargetId);
    Assert.AreNotEqual(lOuterTargetId, lLexicalTargetId,
      'Each routine local target keeps its own declaration identity.');
  end;
end;

procedure TWithBinderTests.RoutineLocalInheritedMembersNeverBindElsewhere;
var
  lBinding: TDelphiSemanticWithBinding;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lGuid: TGUID;
  lGuidText: string;
  lInspected: Integer;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lProblems: string;
  lRoot: string;
begin
  // DS-685 C7 review: an owner-identity lookup is direct only, so a direct miss
  // on a routine-local class must not be read as "not a member".
  CreateGUID(lGuid);
  lGuidText := StringReplace(StringReplace(GUIDToString(lGuid), '{', '', [rfReplaceAll]),
    '}', '', [rfReplaceAll]);
  lRoot := WithBinderTempPath('local-inherited-members-' + lGuidText);
  TDirectory.CreateDirectory(lRoot);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'LocalInheritedMembers.pas');
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit LocalInheritedMembers;'#13#10 +
    'interface'#13#10 +
    'type'#13#10 +
    '  TBase = class'#13#10 +
    '  public'#13#10 +
    '    Caption: string;'#13#10 +
    '    procedure Ping;'#13#10 +
    '  end;'#13#10 +
    '  TOuter = class'#13#10 +
    '  public'#13#10 +
    '    Caption: string;'#13#10 +
    '    procedure Ping;'#13#10 +
    '  end;'#13#10 +
    '  TOwner = class'#13#10 +
    '  public'#13#10 +
    '    Caption: string;'#13#10 +
    '    procedure Ping;'#13#10 +
    '    procedure RunWithoutOuter;'#13#10 +
    '  end;'#13#10 +
    'procedure RunWithOuter(lOuter: TOuter);'#13#10 +
    'procedure RunWithAlias(lOuter: TOuter);'#13#10 +
    'implementation'#13#10 +
    'procedure TBase.Ping;'#13#10 +
    'begin'#13#10 +
    'end;'#13#10 +
    'procedure TOuter.Ping;'#13#10 +
    'begin'#13#10 +
    'end;'#13#10 +
    'procedure TOwner.Ping;'#13#10 +
    'begin'#13#10 +
    'end;'#13#10 +
    'procedure RunWithOuter(lOuter: TOuter);'#13#10 +
    'type'#13#10 +
    '  TLocal = class(TBase)'#13#10 +
    '    Extra: Integer;'#13#10 +
    '  end;'#13#10 +
    'var'#13#10 +
    '  lLocal: TLocal;'#13#10 +
    'begin'#13#10 +
    '  with lOuter do'#13#10 +
    '    with lLocal do'#13#10 +
    '    begin'#13#10 +
    '      Extra := 1;'#13#10 +
    '      Caption := '''';'#13#10 +
    '      Ping;'#13#10 +
    '      Free;'#13#10 +
    '    end;'#13#10 +
    'end;'#13#10 +
    'procedure RunWithAlias(lOuter: TOuter);'#13#10 +
    'type'#13#10 +
    '  TLocal = TBase;'#13#10 +
    'var'#13#10 +
    '  lLocal: TLocal;'#13#10 +
    'begin'#13#10 +
    '  with lOuter do'#13#10 +
    '    with lLocal do'#13#10 +
    '    begin'#13#10 +
    '      Caption := '''';'#13#10 +
    '      Ping;'#13#10 +
    '    end;'#13#10 +
    'end;'#13#10 +
    'procedure TOwner.RunWithoutOuter;'#13#10 +
    'type'#13#10 +
    '  TLocal = class(TBase)'#13#10 +
    '    Extra: Integer;'#13#10 +
    '  end;'#13#10 +
    'var'#13#10 +
    '  lLocal: TLocal;'#13#10 +
    'begin'#13#10 +
    '  with lLocal do'#13#10 +
    '  begin'#13#10 +
    '    Extra := 1;'#13#10 +
    '    Caption := '''';'#13#10 +
    '    Ping;'#13#10 +
    '    Free;'#13#10 +
    '  end;'#13#10 +
    'end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success, 'The local inherited member fixture must extract from source.');
  lFacts := TDelphiSemanticWithBinder.BindProject('', nil, [lModel]);
  lProblems := '';
  lInspected := 0;
  for lBinding in lFacts.Bindings do
  begin
    // Every binding is inspected, including the outer WITH on lOuter.
    if (Length(lBinding.Selectors) > 0) and
      SameText(lBinding.Selectors[High(lBinding.Selectors)].SelectorText, 'lLocal') then
      Inc(lInspected);
    lProblems := lProblems + RoutineLocalInheritedReferenceProblem(lBinding, 'Caption') +
      RoutineLocalInheritedReferenceProblem(lBinding, 'Ping') +
      RoutineLocalInheritedReferenceProblem(lBinding, 'Free');
  end;
  Assert.AreEqual(3, lInspected, 'All three WITH statements on lLocal must be bound.');
  Assert.AreEqual('', lProblems,
    'Inherited members of a routine-local class must be refused or bound to TBase.');
end;

procedure TWithBinderTests.SelectorIdentityUsesTheDeclaringUnitScope;
var
  lBinding: TDelphiSemanticWithBinding;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lLocalScopeId: string;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticApiOptions;
  lPairScopeId: string;
  lProjectPath: string;
  lRoot: string;
  lRoutine: TDelphiSemanticRoutine;
  lSeen: string;
  lSelector: TDelphiSemanticWithSelectorBinding;
  c: Char;

  procedure AssertUnitIdentity(const aCase, aUnitName, aTypeName: string);
  begin
    Assert.AreEqual('resolved', lSelector.Status, aCase + ': ' + lSelector.ReasonCode);
    Assert.AreEqual(aTypeName, lSelector.TypeIdentity.Name, aCase);
    Assert.AreEqual(aUnitName, lSelector.TypeIdentity.UnitName, aCase);
    Assert.AreEqual('unit', lSelector.TypeIdentity.ScopeKind, aCase);
    Assert.IsNotEmpty(lSelector.TypeIdentity.SemanticSymbolId, aCase);
  end;

begin
  lRoot := WithBinderTempPath('declaring-unit-scope-' + TPath.GetGUIDFileName);
  TDirectory.CreateDirectory(lRoot);
  lProjectPath := TPath.Combine(lRoot, 'DeclaringScope.dproj');
  TFile.WriteAllText(TPath.Combine(lRoot, 'DeclaringScope.dpr'),
    'program DeclaringScope;'#13#10 +
    'uses MaskConsumer in ''MaskConsumer.pas'';'#13#10 +
    'begin'#13#10'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(lProjectPath,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>DeclaringScope.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="MaskProvider.pas"/>' +
    '<DCCReference Include="TableDecl.pas"/>' +
    '<DCCReference Include="MaskConsumer.pas"/></ItemGroup></Project>',
    TEncoding.ASCII);
  // The final record type lives in MaskProvider; the field and parameter that reach it
  // are declared in TableDecl (like maxTdb DatFile.Maske and MaskType).
  TFile.WriteAllText(TPath.Combine(lRoot, 'MaskProvider.pas'),
    'unit MaskProvider;'#13#10 +
    'interface'#13#10 +
    'type'#13#10 +
    '  TMaskEntry = record Width: Integer; end;'#13#10 +
    '  PMaskEntry = ^TMaskEntry;'#13#10 +
    '  TMaskArray = array[1..4] of PMaskEntry;'#13#10 +
    'implementation'#13#10'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'TableDecl.pas'),
    'unit TableDecl;'#13#10 +
    'interface'#13#10 +
    'uses MaskProvider;'#13#10 +
    'type'#13#10 +
    '  TTable = record Mask: TMaskArray; end;'#13#10 +
    '  PTable = ^TTable;'#13#10 +
    'var'#13#10 +
    '  Tables: array[1..2] of PTable;'#13#10 +
    'procedure CopyMask(const aMask: TMaskArray);'#13#10 +
    'implementation'#13#10 +
    'procedure CopyMask(const aMask: TMaskArray);'#13#10 +
    'begin'#13#10 +
    '  with aMask[1]^ do Width := 1;'#13#10 +
    'end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'MaskConsumer.pas'),
    'unit MaskConsumer;'#13#10 +
    'interface'#13#10 +
    'type'#13#10 +
    '  TCell = record Value: Integer; end;'#13#10 +
    '  TCellArray = array[1..4] of TCell;'#13#10 +
    '  PCellArray = ^TCellArray;'#13#10 +
    'procedure UseCells(aCells: PCellArray);'#13#10 +
    'procedure UseField;'#13#10 +
    'procedure UseNested;'#13#10 +
    'procedure UseLocal;'#13#10 +
    'procedure UseInline;'#13#10 +
    'procedure UsePair(aValue: Integer;aOther : Integer );'#13#10 +
    'implementation'#13#10 +
    'uses MaskProvider, TableDecl;'#13#10 +
    'procedure UseCells(aCells: PCellArray);'#13#10 +
    'begin'#13#10 +
    '  with aCells^[1] do Value := 1;'#13#10 +
    'end;'#13#10 +
    'procedure UseField;'#13#10 +
    'begin'#13#10 +
    '  with Tables[1]^.Mask[2]^ do Width := 2;'#13#10 +
    'end;'#13#10 +
    'procedure UseNested;'#13#10 +
    'begin'#13#10 +
    '  with Tables[1]^ do'#13#10 +
    '    with Mask[2]^ do Width := 3;'#13#10 +
    'end;'#13#10 +
    'procedure UseLocal;'#13#10 +
    'type TMaskEntry = record LocalOnly: Integer; end;'#13#10 +
    'var lEntry: TMaskEntry;'#13#10 +
    'begin'#13#10 +
    '  with lEntry do LocalOnly := 4;'#13#10 +
    'end;'#13#10 +
    'procedure UseInline;'#13#10 +
    'var lMasks: array[1..2] of PMaskEntry;'#13#10 +
    'begin'#13#10 +
    '  with lMasks[1]^ do Width := 5;'#13#10 +
    'end;'#13#10 +
    // The body repeats the header with different line breaks and spacing only.
    'procedure UsePair(aValue: Integer;'#13#10 +
    '  aOther: Integer);'#13#10 +
    'type TPairLocal = record PairOnly: Integer; end;'#13#10 +
    'var lPair: TPairLocal;'#13#10 +
    '  procedure Inner;'#13#10 +
    '  begin'#13#10 +
    '    with lPair do PairOnly := 6;'#13#10 +
    '  end;'#13#10 +
    'begin'#13#10 +
    '  Inner;'#13#10 +
    'end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := lProjectPath;
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  lLocalScopeId := '';
  lPairScopeId := '';
  for lModel in lFacts.UnitModels do
    if SameText(lModel.UnitName, 'MaskConsumer') then
    begin
      Assert.AreEqual('ast', lModel.ScopeModelStatus);
      for lRoutine in lModel.Routines do
        if SameText(lRoutine.SectionKind, 'implementation') and
          SameText(lRoutine.Name, 'UseLocal') then
          lLocalScopeId := lRoutine.ScopeId
        else if SameText(lRoutine.SectionKind, 'implementation') and
          SameText(lRoutine.Name, 'UsePair') then
          lPairScopeId := lRoutine.ScopeId;
    end;
  Assert.IsNotEmpty(lLocalScopeId);
  Assert.IsNotEmpty(lPairScopeId);
  lSeen := '';
  for lBinding in lFacts.Bindings do
  begin
    if Length(lBinding.Selectors) = 0 then
      Continue;
    lSelector := lBinding.Selectors[High(lBinding.Selectors)];
    if SameText(lBinding.RoutineName, 'CopyMask') then
    begin
      // Parameter declared in TableDecl; its final type comes from MaskProvider.
      AssertUnitIdentity('parameter', 'MaskProvider', 'TMaskEntry');
      Assert.AreEqual('TMaskEntry', ReceiverOf(lBinding, 'Width', 'member'));
      lSeen := lSeen + 'P';
    end else if SameText(lBinding.RoutineName, 'UseCells') then
    begin
      // Same-unit parameter reached through its interface header coordinates.
      AssertUnitIdentity('same-unit parameter', 'MaskConsumer', 'TCell');
      lSeen := lSeen + 'C';
    end else if SameText(lBinding.RoutineName, 'UseField') then
    begin
      AssertUnitIdentity('field', 'MaskProvider', 'TMaskEntry');
      lSeen := lSeen + 'F';
    end else if SameText(lBinding.RoutineName, 'UseNested') and
      SameText(lSelector.SelectorText, 'Mask[2]^') then
    begin
      AssertUnitIdentity('bound field', 'MaskProvider', 'TMaskEntry');
      lSeen := lSeen + 'N';
    end else if SameText(lBinding.RoutineName, 'UseLocal') then
    begin
      // Negative control: the routine-local homonym keeps its routine identity.
      Assert.AreEqual('resolved', lSelector.Status, lSelector.ReasonCode);
      Assert.AreEqual('routine', lSelector.TypeIdentity.ScopeKind);
      Assert.AreEqual(lLocalScopeId, lSelector.TypeIdentity.OwnerScopeId);
      Assert.AreEqual('TMaskEntry', ReceiverOf(lBinding, 'LocalOnly', 'member'));
      lSeen := lSeen + 'L';
    end else if SameText(lBinding.RoutineName, 'UseInline') then
    begin
      // Negative control: an inline local type cannot prove the scope of an imported
      // final type, so the identity stays unproven (blank), which member safety refuses.
      Assert.AreEqual('resolved', lSelector.Status, lSelector.ReasonCode);
      Assert.AreEqual('TMaskEntry', lSelector.TypeName);
      Assert.IsEmpty(lSelector.TypeIdentity.Name, 'An unproven origin must stay blank.');
      Assert.IsEmpty(lSelector.TypeIdentity.UnitName, 'An unproven origin must stay blank.');
      lSeen := lSeen + 'I';
    end else if SameText(lBinding.RoutineName, 'Inner') then
    begin
      // Header and body differ only by whitespace, so the parent scope stays valid.
      Assert.AreEqual('resolved', lSelector.Status, lSelector.ReasonCode);
      Assert.AreEqual('TPairLocal', lSelector.TypeIdentity.Name);
      Assert.AreEqual('routine', lSelector.TypeIdentity.ScopeKind);
      Assert.AreEqual(lPairScopeId, lSelector.TypeIdentity.OwnerScopeId);
      Assert.AreEqual('TPairLocal', ReceiverOf(lBinding, 'PairOnly', 'member'));
      lSeen := lSeen + 'W';
    end;
  end;
  // Binding order follows the units, so compare the set of cases.
  Assert.AreEqual(7, Length(lSeen), 'Every source-backed WITH must be bound once: ' + lSeen);
  for c in 'PCFNLIW' do
    Assert.IsTrue(Pos(c, lSeen) > 0, 'Missing case ' + c + ' in ' + lSeen);
end;

procedure TWithBinderTests.UnitReceiverWithUnindexedAncestorNeverBindsElsewhere(
  const aBaseTypeName: string);
var
  lBinding: TDelphiSemanticWithBinding;
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lInnerDeclaration: string;
  lInspected: Integer;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  // DS-700: an unindexed ancestor may own Count. A direct miss is not proof
  // that either an outer receiver or a unit-scope homonym owns the name.
  if SameText(aBaseTypeName, 'record') then
    lInnerDeclaration := '  TInner = record Extra: Integer; end;'#13#10
  else
    lInnerDeclaration := '  TInner = class(' + aBaseTypeName + ')'#13#10 +
      '  public'#13#10'    Extra: Integer;'#13#10'  end;'#13#10;
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := WithBinderTempPath('UnitAncestor-' + aBaseTypeName + '.pas');
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit UnitAncestor;'#13#10'interface'#13#10'uses System.Classes;'#13#10 +
    'type'#13#10'  TOuter = record Count: Integer; end;'#13#10 + lInnerDeclaration +
    'var'#13#10'  Outer: TOuter;'#13#10'  Inner: TInner;'#13#10 +
    '  Count: Integer;'#13#10 +
    'procedure RunOuter;'#13#10'procedure RunLexical;'#13#10'implementation'#13#10 +
    'procedure RunOuter;'#13#10'begin'#13#10'  with Outer do'#13#10 +
    '    with Inner do'#13#10'    begin'#13#10 +
    '      Extra := 1;'#13#10'      Count := Count + 1;'#13#10'    end;'#13#10'end;'#13#10 +
    'procedure RunLexical;'#13#10'begin'#13#10'  with Inner do'#13#10'  begin'#13#10 +
    '    Extra := 1;'#13#10'    Count := Count + 1;'#13#10'  end;'#13#10'end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success, 'Unit receiver fixture must extract.');
  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  lInspected := 0;
  for lBinding in lBindings do
    if (Length(lBinding.Selectors) > 0) and
      SameText(lBinding.Selectors[High(lBinding.Selectors)].SelectorText, 'Inner') then
    begin
      Inc(lInspected);
      Assert.AreEqual('resolved', lBinding.Selectors[High(lBinding.Selectors)].Status);
      Assert.AreEqual('TInner', ReceiverOf(lBinding, 'Extra', 'member'));
      Assert.AreEqual(2, CountReferences(lBinding, 'Count'));
      if SameText(aBaseTypeName, 'record') then
      begin
        if SameText(lBinding.RoutineName, 'RunOuter') then
          Assert.AreEqual('TOuter', ReceiverOf(lBinding, 'Count', 'member'))
        else
          Assert.IsTrue(HasReference(lBinding, 'Count', 'lexical'));
      end else begin
        Assert.IsTrue(HasReference(lBinding, 'Count', 'unsupported'),
          aBaseTypeName + ': Count must not fall through to an outer or lexical homonym.');
        Assert.IsFalse(HasReference(lBinding, 'Count', 'member'));
        Assert.IsFalse(HasReference(lBinding, 'Count', 'lexical'));
      end;
    end;
  Assert.AreEqual(2, lInspected, 'Inspect both nested and lexical receiver paths.');
end;

procedure TWithBinderTests.ParameterTypesResolveInTheEnclosingScope;
var
  lBinding: TDelphiSemanticWithBinding;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lOuterScopeId: string;
  lRoot: string;
  lRoutine: TDelphiSemanticRoutine;
  lSeen: string;
  lSelector: TDelphiSemanticWithSelectorBinding;
  c: Char;

  // Delphi resolves parameter types in the scope that encloses the routine heading, so
  // a routine's own local homonym never names its parameter's type (verified with a
  // dcc64 probe: Count binds to the parameter's unit-level record field).
  procedure AssertUnitParameterType(const aCase, aTypeName: string);
  begin
    Assert.AreNotEqual('routine', lSelector.TypeIdentity.ScopeKind,
      aCase + ': a routine-local homonym must never type a parameter.');
    if SameText(lSelector.Status, 'resolved') and (lSelector.TypeIdentity.Name <> '') then
    begin
      Assert.AreEqual(aTypeName, lSelector.TypeIdentity.Name, aCase);
      Assert.AreEqual('unit', lSelector.TypeIdentity.ScopeKind, aCase);
    end;
    Assert.IsFalse(HasReference(lBinding, 'Count', 'lexical'),
      aCase + ': Count must not bind to the global variable.');
    Assert.IsFalse(HasReference(lBinding, 'Other', 'member'), aCase);
  end;

begin
  lRoot := WithBinderTempPath('parameter-scope-' + TPath.GetGUIDFileName);
  TDirectory.CreateDirectory(lRoot);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'ParameterScope.pas');
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit ParameterScope;'#13#10 +
    'interface'#13#10 +
    'type'#13#10 +
    '  TFoo = record Count: Integer; end;'#13#10 +
    '  TFooArr = array[0..1] of TFoo;'#13#10 +
    'var'#13#10 +
    '  Count: Integer;'#13#10 +
    'procedure OpenRun(const aItems: array of TFoo);'#13#10 +
    'procedure ArrayRun(var aArr: TFooArr);'#13#10 +
    'procedure PlainRun(var aOne: TFoo);'#13#10 +
    'procedure OuterRun;'#13#10 +
    'implementation'#13#10 +
    'procedure OpenRun(const aItems: array of TFoo);'#13#10 +
    'type TFoo = record Other: Integer; end;'#13#10 +
    'begin'#13#10 +
    '  with aItems[0] do Count := 1;'#13#10 +
    'end;'#13#10 +
    'procedure ArrayRun(var aArr: TFooArr);'#13#10 +
    'type'#13#10 +
    '  TFoo = record Other: Integer; end;'#13#10 +
    '  TFooArr = array[0..1] of TFoo;'#13#10 +
    'begin'#13#10 +
    '  with aArr[1] do Count := 2;'#13#10 +
    'end;'#13#10 +
    'procedure PlainRun(var aOne: TFoo);'#13#10 +
    'type TFoo = record Other: Integer; end;'#13#10 +
    'begin'#13#10 +
    '  with aOne do Count := 3;'#13#10 +
    'end;'#13#10 +
    'procedure OuterRun;'#13#10 +
    'type TOuterRec = record Inner: Integer; end;'#13#10 +
    '  procedure NestedRun(var aRec: TOuterRec);'#13#10 +
    '  begin'#13#10 +
    '    with aRec do Inner := 4;'#13#10 +
    '  end;'#13#10 +
    'begin'#13#10 +
    'end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success, 'The parameter scope fixture must extract from source.');
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  lOuterScopeId := '';
  for lRoutine in lModel.Routines do
    if SameText(lRoutine.Name, 'OuterRun') and SameText(lRoutine.SectionKind, 'implementation') then
      lOuterScopeId := lRoutine.ScopeId;
  Assert.IsNotEmpty(lOuterScopeId);
  lFacts := TDelphiSemanticWithBinder.BindProject('', nil, [lModel]);
  lSeen := '';
  for lBinding in lFacts.Bindings do
  begin
    if Length(lBinding.Selectors) <> 1 then
      Continue;
    lSelector := lBinding.Selectors[0];
    if SameText(lBinding.RoutineName, 'OpenRun') then
    begin
      AssertUnitParameterType('open array', 'TFoo');
      lSeen := lSeen + 'O';
    end else if SameText(lBinding.RoutineName, 'ArrayRun') then
    begin
      AssertUnitParameterType('identifier array', 'TFoo');
      lSeen := lSeen + 'A';
    end else if SameText(lBinding.RoutineName, 'PlainRun') then
    begin
      AssertUnitParameterType('plain parameter', 'TFoo');
      lSeen := lSeen + 'P';
    end else if SameText(lBinding.RoutineName, 'NestedRun') then
    begin
      // Positive control: a nested heading sees its parent's local types.
      Assert.AreEqual('resolved', lSelector.Status, lSelector.ReasonCode);
      Assert.AreEqual('TOuterRec', lSelector.TypeIdentity.Name);
      Assert.AreEqual('routine', lSelector.TypeIdentity.ScopeKind);
      Assert.AreEqual(lOuterScopeId, lSelector.TypeIdentity.OwnerScopeId);
      Assert.AreEqual('TOuterRec', ReceiverOf(lBinding, 'Inner', 'member'));
      lSeen := lSeen + 'N';
    end;
  end;
  Assert.AreEqual(4, Length(lSeen), 'Every source-backed WITH must be bound once: ' + lSeen);
  for c in 'OAPN' do
    Assert.IsTrue(Pos(c, lSeen) > 0, 'Missing case ' + c + ' in ' + lSeen);
end;

procedure TWithBinderTests.MalformedPointerAliasOwnersAndAmbiguousPointeesAreRefused;
var
  i: Integer;
  j: Integer;
  lBinding: TDelphiSemanticWithBinding;
  lDeclaration: TDelphiSemanticDeclaration;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lModel: TDelphiSemanticUnitModel;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lSeen: Boolean;
  lUnitNode: TDelphiSemanticDeclaration;
  lUnitNodeCount: Integer;
begin
  lModel := BuildPointerAliasScopeModel;
  lUnitNode := Default(TDelphiSemanticDeclaration);
  lUnitNodeCount := 0;
  for lDeclaration in lModel.Declarations do
    if SameText(lDeclaration.Name, 'TNode') and
      SameText(lDeclaration.ScopeKind, 'unit') then
    begin
      Inc(lUnitNodeCount);
      lUnitNode := lDeclaration;
    end;
  Assert.AreEqual(1, lUnitNodeCount, 'The unmutated source has one unit pointee.');
  Assert.IsNotEmpty(lUnitNode.SymbolId);
  lFacts := TDelphiSemanticWithBinder.BindProject('', nil, [lModel]);
  lSeen := False;
  for lBinding in lFacts.Bindings do
    if SameText(lBinding.RoutineName, 'UnitAliasRun') then
    begin
      Assert.IsFalse(lSeen, 'The unmutated unit alias has one binding.');
      lSeen := True;
      Assert.AreEqual(1, Integer(Length(lBinding.Selectors)));
      Assert.AreEqual('resolved', lBinding.Selectors[0].Status,
        lBinding.Selectors[0].ReasonCode);
      Assert.AreEqual(lModel.UnitName, lBinding.Selectors[0].TypeIdentity.UnitName);
      Assert.AreEqual('unit', lBinding.Selectors[0].TypeIdentity.ScopeKind);
      Assert.AreEqual(LowerCase(lModel.UnitName),
        lBinding.Selectors[0].TypeIdentity.OwnerScopeId);
      Assert.AreEqual(lUnitNode.SymbolId,
        lBinding.Selectors[0].TypeIdentity.SemanticSymbolId);
      Assert.IsNotEmpty(lBinding.Selectors[0].TypeIdentity.DeclaredId.Value);
      Assert.AreEqual(lModel.FileName,
        lBinding.Selectors[0].TypeIdentity.SourceRange.FileName);
      Assert.AreEqual(lUnitNode.Line,
        lBinding.Selectors[0].TypeIdentity.SourceRange.Line);
      Assert.AreEqual(lUnitNode.Column,
        lBinding.Selectors[0].TypeIdentity.SourceRange.Column);
    end;
  Assert.IsTrue(lSeen, 'The unmutated source-backed unit alias must resolve.');
  for i := 0 to 2 do
  begin
    lModels := [lModel];
    lModels[0].Declarations := Copy(lModel.Declarations);
    for j := 0 to High(lModels[0].Declarations) do
      if SameText(lModels[0].Declarations[j].Name, 'PUnitNode') then
      begin
        if i = 0 then
          lModels[0].Declarations[j].OwnerScopeId := 'wrong-unit'
        else if i = 1 then
          lModels[0].Declarations[j].ScopeKind := 'unknown';
        Break;
      end;
    if i = 2 then
    begin
      for lDeclaration in lModel.Declarations do
        if SameText(lDeclaration.Name, 'TNode') and
          SameText(lDeclaration.ScopeKind, 'unit') then
        begin
          j := Length(lModels[0].Declarations);
          SetLength(lModels[0].Declarations, j + 1);
          lModels[0].Declarations[j] := lDeclaration;
          lModels[0].Declarations[j].SymbolId := lDeclaration.SymbolId + ':duplicate';
          lModels[0].Declarations[j].Line := lDeclaration.Line + 1;
          Break;
        end;
    end;
    lFacts := TDelphiSemanticWithBinder.BindProject('', nil, lModels);
    lSeen := False;
    for lBinding in lFacts.Bindings do
      if SameText(lBinding.RoutineName, 'UnitAliasRun') then
      begin
        Assert.IsFalse(lSeen, 'The mutated unit alias has one binding.');
        lSeen := True;
        Assert.AreEqual(1, Integer(Length(lBinding.Selectors)));
        Assert.AreEqual('unresolved', lBinding.Selectors[0].Status);
        Assert.AreEqual('SELECTOR_TYPE_NOT_RESOLVED',
          lBinding.Selectors[0].ReasonCode,
          'Malformed alias owner or ambiguous pointee must fail closed.');
      end;
    Assert.IsTrue(lSeen, 'The source-backed unit alias binding must be retained.');
  end;
end;


function TWithBinderTests.LoadModel: TDelphiSemanticUnitModel;
var
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('WithBinder', 'WithBinderUnit.pas');
  lOptions.ProjectContextApplied := True;
  Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(Result.Success);
end;

function TWithBinderTests.LoadBareReceiverSafetyModels: TArray<TDelphiSemanticUnitModel>;
var
  i: Integer;
  lOptions: TDelphiSemanticModelOptions;
  lUnitName: string;
begin
  SetLength(Result, 3);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  for i := 0 to 2 do
  begin
    case i of
      0: lUnitName := 'ReceiverSafetyHidden';
      1: lUnitName := 'ReceiverSafetyBareOwner';
    else
      lUnitName := 'ReceiverSafetyBareCaller';
    end;
    lOptions.SourceFileName := FixturePath('WithBinder\ReceiverSafetyIdentity',
      lUnitName + '.pas');
    Result[i] := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
    Assert.IsTrue(Result[i].Success, lUnitName + ' source model');
  end;
end;

function TWithBinderTests.LoadReceiverSafetyModels: TArray<TDelphiSemanticUnitModel>;
var
  i: Integer;
  lOptions: TDelphiSemanticModelOptions;
  lUnitName: string;
begin
  SetLength(Result, 4);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  for i := 0 to 3 do
  begin
    case i of
      0: lUnitName := 'ReceiverSafetyHidden';
      1: lUnitName := 'ReceiverSafetyAlias';
      2: lUnitName := 'ReceiverSafetyOwner';
    else
      lUnitName := 'ReceiverSafetyCaller';
    end;
    lOptions.SourceFileName := FixturePath('WithBinder\ReceiverSafetyIdentity',
      lUnitName + '.pas');
    Result[i] := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
    Assert.IsTrue(Result[i].Success, lUnitName + ' source model');
  end;
end;

function TWithBinderTests.HasReference(const aBinding: TDelphiSemanticWithBinding;
  const aName, aClassification: string): Boolean;
var
  lReference: TDelphiSemanticBoundReference;
begin
  for lReference in aBinding.References do
    if SameText(lReference.Name, aName) and SameText(lReference.Classification, aClassification) then
      Exit(True);

  Result := False;
end;

function TWithBinderTests.HasAnyReference(const aBinding: TDelphiSemanticWithBinding;
  const aName: string): Boolean;
var
  lReference: TDelphiSemanticBoundReference;
begin
  for lReference in aBinding.References do
    if SameText(lReference.Name, aName) then
      Exit(True);

  Result := False;
end;

function TWithBinderTests.ReceiverOf(const aBinding: TDelphiSemanticWithBinding; const aName,
  aClassification: string): string;
var
  lReference: TDelphiSemanticBoundReference;
begin
  for lReference in aBinding.References do
    if SameText(lReference.Name, aName) and SameText(lReference.Classification, aClassification) then
      Exit(lReference.ReceiverTypeName);

  Result := '';
end;

function TWithBinderTests.CountReferences(const aBinding: TDelphiSemanticWithBinding;
  const aName: string): Integer;
var
  lReference: TDelphiSemanticBoundReference;
begin
  Result := 0;
  for lReference in aBinding.References do
    if SameText(lReference.Name, aName) then
      Inc(Result);
end;

function TWithBinderTests.LookupSourceOf(const aBinding: TDelphiSemanticWithBinding; const aName,
  aClassification: string): string;
var
  lReference: TDelphiSemanticBoundReference;
begin
  for lReference in aBinding.References do
    if SameText(lReference.Name, aName) and SameText(lReference.Classification, aClassification) then
      Exit(lReference.LookupSource);

  Result := '';
end;

function TWithBinderTests.ReasonOf(const aBinding: TDelphiSemanticWithBinding; const aName,
  aClassification: string): string;
var
  lReference: TDelphiSemanticBoundReference;
begin
  for lReference in aBinding.References do
    if SameText(lReference.Name, aName) and SameText(lReference.Classification, aClassification) then
      Exit(lReference.ReasonCode);

  Result := '';
end;

function TWithBinderTests.HasInventorySymbol(const aInventory: TDelphiSemanticRemoveWithInventory;
  const aName, aSymbolClass, aRoutineName: string): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  for lSymbol in aInventory.Symbols do
    if SameText(lSymbol.Name, aName) and SameText(lSymbol.SymbolClass, aSymbolClass) and
      SameText(lSymbol.RoutineName, aRoutineName) then
      Exit(True);

  Result := False;
end;

function TWithBinderTests.TryFindInventorySymbol(const aInventory: TDelphiSemanticRemoveWithInventory;
  const aName, aSymbolClass, aOwnerName: string; out aSymbol:
  TDelphiSemanticInventorySymbol): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  for lSymbol in aInventory.Symbols do
  begin
    if SameText(lSymbol.Name, aName) and SameText(lSymbol.SymbolClass, aSymbolClass) and
      SameText(lSymbol.OwnerName, aOwnerName) then
    begin
      aSymbol := lSymbol;
      Exit(True);
    end;
  end;

  aSymbol := Default(TDelphiSemanticInventorySymbol);
  Result := False;
end;

procedure TWithBinderTests.ResolvesSelectorTypesAndClassifiesBodyIdentifiers;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  Assert.AreEqual(10, Integer(Length(lBindings)));
  Assert.AreEqual(1, Integer(Length(lBindings[0].Selectors)));
  Assert.AreEqual('lFirst', lBindings[0].Selectors[0].SelectorText);
  Assert.AreEqual('resolved', lBindings[0].Selectors[0].Status);
  Assert.AreEqual('TFirstRecord', lBindings[0].Selectors[0].TypeName);
  Assert.IsTrue(HasReference(lBindings[0], 'FirstOnly', 'member'));
  Assert.IsTrue(HasReference(lBindings[0], 'aParamValue', 'lexical'));
  Assert.IsTrue(HasReference(lBindings[0], 'lLocalValue', 'lexical'));
  Assert.IsTrue(HasReference(lBindings[0], 'lSecond.SecondOnly', 'unsupported'));
  Assert.IsTrue(HasReference(lBindings[0], 'FirstOnly[0]', 'unsupported'));
  Assert.IsTrue(HasReference(lBindings[0], 'MissingValue', 'unresolved'));
  Assert.IsFalse(HasAnyReference(lBindings[0], 'PhantomMember'));
  Assert.IsFalse(HasAnyReference(lBindings[0], 'BracePhantom'));
  Assert.IsFalse(HasAnyReference(lBindings[0], 'ParenPhantom'));
end;

procedure TWithBinderTests.BindingsExposeSourceRangesForDakPlanner;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  lBinding := lBindings[0];

  Assert.AreEqual(lModel.WithStatements[0].Line, lBinding.Line);
  Assert.AreEqual(lModel.WithStatements[0].Column, lBinding.Column);
  Assert.AreEqual(lModel.WithStatements[0].EndLine, lBinding.EndLine);
  Assert.AreEqual(lModel.WithStatements[0].EndColumn, lBinding.EndColumn);
  Assert.AreEqual(lModel.WithStatements[0].BodyLine, lBinding.BodyLine);
  Assert.AreEqual(lModel.WithStatements[0].BodyColumn, lBinding.BodyColumn);
  Assert.AreEqual(lModel.WithStatements[0].BodyEndLine, lBinding.BodyEndLine);
  Assert.AreEqual(lModel.WithStatements[0].BodyEndColumn, lBinding.BodyEndColumn);
  Assert.AreEqual(lModel.WithStatements[0].SelectorText, lBinding.SelectorText);
end;

procedure TWithBinderTests.MultipleSelectorsPreferInnermostReceiver;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  Assert.AreEqual(2, Integer(Length(lBindings[1].Selectors)));
  Assert.AreEqual('TFirstRecord', lBindings[1].Selectors[0].TypeName);
  Assert.AreEqual('TSecondRecord', lBindings[1].Selectors[1].TypeName);
  Assert.IsTrue(HasReference(lBindings[1], 'Shared', 'member'));
  Assert.AreEqual('TSecondRecord', ReceiverOf(lBindings[1], 'Shared', 'member'));
  Assert.IsTrue(HasReference(lBindings[1], 'SecondOnly', 'member'));
  Assert.IsTrue(HasReference(lBindings[1], 'FirstOnly', 'member'));
end;

procedure TWithBinderTests.AmbiguousReceiverMembersClassifyAsAmbiguous;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lLength: Integer;
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;
  lLength := Length(lModel.Members);
  SetLength(lModel.Members, lLength + 1);
  lMember := lModel.Members[0];
  lMember.OwnerName := 'TFirstRecord';
  lMember.Name := 'FirstOnly';
  lModel.Members[lLength] := lMember;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  Assert.IsTrue(HasReference(lBindings[0], 'FirstOnly', 'ambiguous'));
end;

procedure TWithBinderTests.ClassMethodWithBindingUsesOwnedRoutineTypeForInheritedProtectedMembers;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lExpandedCount: Integer;
  lOwnerCount: Integer;
  lPath: string;
  lSource: string;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  lPath := WithBinderTempPath('withbinder-current-type-regression.pas');
  lSource :=
    'unit WithBinderCurrentTypeRegression;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TBase = class' + sLineBreak +
    '  protected' + sLineBreak +
    '    BaseValue: Integer;' + sLineBreak +
    '  end;' + sLineBreak +
    '  TChild = class(TBase)' + sLineBreak +
    '  public' + sLineBreak +
    '    class procedure Run;' + sLineBreak +
    '  end;' + sLineBreak +
    'implementation' + sLineBreak +
    'class procedure TChild.Run;' + sLineBreak +
    'var' + sLineBreak +
    '  lChild: TChild;' + sLineBreak +
    'begin' + sLineBreak +
    '  with lChild do' + sLineBreak +
    '    BaseValue := 1;' + sLineBreak +
    'end;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.ASCII);
  try
    lOptions := Default(TDelphiSemanticModelOptions);
    lOptions.SourceFileName := lPath;
    lOptions.ProjectContextApplied := True;
    lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
    Assert.IsTrue(lModel.Success);

    lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

    Assert.AreEqual(1, Integer(Length(lBindings)));
    lBinding := lBindings[0];
    Assert.AreEqual('TChild.Run', lBinding.RoutineName);
    Assert.IsTrue(HasReference(lBinding, 'BaseValue', 'member'),
      'Inherited protected receiver members need the owned routine type as access context.');
    Assert.AreEqual('TBase', ReceiverOf(lBinding, 'BaseValue', 'member'));
    lFacts := TDelphiSemanticWithBinder.BindProject('', nil, [lModel]);
    lExpandedCount := 0;
    lOwnerCount := 0;
    for lSymbol in lFacts.Symbols do
      if SameText(lSymbol.Name, 'BaseValue') then
      begin
        if SameText(lSymbol.SymbolClass, 'member') and
          SameText(lSymbol.OwnerName, 'TBase') then
          Inc(lOwnerCount)
        else if SameText(lSymbol.SymbolClass, 'field') and
          SameText(lSymbol.OwnerName, 'TChild') then
        begin
          Inc(lExpandedCount);
          Assert.AreEqual('TBase', lSymbol.SourceOwnerType);
          Assert.AreEqual('WithBinderCurrentTypeRegression',
            lSymbol.AccessOwnerIdentity.UnitName);
          Assert.AreEqual('TChild', lSymbol.AccessOwnerIdentity.Name);
          Assert.IsTrue(lSymbol.AccessOwnerIdentity.DeclaredId.Value <> '');
          Assert.AreEqual(lPath, lSymbol.AccessOwnerIdentity.SourceRange.FileName);
        end
        else
          Continue;
        Assert.AreEqual('WithBinderCurrentTypeRegression',
          lSymbol.OwnerIdentity.UnitName);
        Assert.AreEqual('TBase', lSymbol.OwnerIdentity.Name);
        Assert.IsTrue(lSymbol.OwnerIdentity.DeclaredId.Value <> '');
        Assert.AreEqual(lPath, lSymbol.OwnerIdentity.SourceRange.FileName);
      end;
    Assert.AreEqual(1, lOwnerCount,
      'Inherited BaseValue must retain its actual declaring TBase owner.');
    Assert.AreEqual(1, lExpandedCount,
      'The derived projection must retain the inherited declaration identity.');
  finally
    if TFile.Exists(lPath) then
      TFile.Delete(lPath);
  end;
end;

procedure TWithBinderTests.InheritedHomonymProjectionsKeepTheirAccessDeclaration;
var
  i: Integer;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lFirstCount: Integer;
  lBinding: TDelphiSemanticWithBinding;
  lFirstBindingCount: Integer;
  lNearestBindingCount: Integer;
  lOptions: TDelphiSemanticApiOptions;
  lProjectPath: string;
  lRoot: string;
  lSecondCount: Integer;
  lSecondBindingCount: Integer;
  lUnknownBindingCount: Integer;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  lRoot := WithBinderTempPath('inherited-homonym');
  TDirectory.CreateDirectory(lRoot);
  lProjectPath := TPath.Combine(lRoot, 'P.dproj');
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P;'#13#10'uses AUnit in ''AUnit.pas'', BUnit in ''BUnit.pas'';'#13#10 +
    'begin'#13#10'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(lProjectPath,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup><ItemGroup>' +
    '<DCCReference Include="BaseUnit.pas"/><DCCReference Include="MidUnit.pas"/>' +
    '<DCCReference Include="AUnit.pas"/><DCCReference Include="BUnit.pas"/>' +
    '</ItemGroup></Project>', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'BaseUnit.pas'),
    'unit BaseUnit;'#13#10'interface'#13#10'type'#13#10 +
    '  TLeaf = record'#13#10'    Value: Integer;'#13#10'  end;'#13#10 +
    '  TBase = class'#13#10'  public'#13#10'    Child: TLeaf;'#13#10 +
    '  end;'#13#10'implementation'#13#10'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'MidUnit.pas'),
    'unit MidUnit;'#13#10'interface'#13#10'uses BaseUnit;'#13#10'type'#13#10 +
    '  TIntermediate = class(TBase) end;'#13#10 +
    'implementation'#13#10'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'AUnit.pas'),
    'unit AUnit;'#13#10'interface'#13#10'uses MidUnit;'#13#10'type'#13#10 +
    '  TDerived = class(TIntermediate) end;'#13#10 +
    '  TWrongLeaf = record OtherValue: Integer; end;'#13#10 +
    '  TGlobalLeaf = record GlobalValue: Integer; end;'#13#10 +
    '  TNearest = record Child: TWrongLeaf; end;'#13#10 +
    'var'#13#10'  Child: TGlobalLeaf;'#13#10 +
    'procedure RunA;'#13#10'procedure RunNearest;'#13#10 +
    'procedure RunUnknown;'#13#10 +
    'implementation'#13#10 +
    'procedure RunA;'#13#10'var'#13#10'  lDerived: TDerived;'#13#10 +
    'begin with lDerived do with Child do Value := 1; end;'#13#10 +
    'procedure RunNearest;'#13#10 +
    'var'#13#10'  lDerived: TDerived;'#13#10 +
    '  lNearest: TNearest;'#13#10 +
    'begin with lDerived do with lNearest do with Child do OtherValue := 1; end;'#13#10 +
    'procedure RunUnknown;'#13#10 +
    'begin with Missing do with Child do Value := 1; end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'BUnit.pas'),
    'unit BUnit;'#13#10'interface'#13#10'uses MidUnit;'#13#10'type'#13#10 +
    '  TDerived = class(TIntermediate) end;'#13#10 +
    'procedure RunB;'#13#10'implementation'#13#10 +
    'procedure RunB;'#13#10'var'#13#10'  lDerived: TDerived;'#13#10 +
    'begin with lDerived do with Child do Value := 2; end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := lProjectPath;
  for i := 0 to 1 do
  begin
    if i = 1 then
      lOptions.ImplicitRootMemberAbsence := TImplicitRootAbsenceStub.Create;
    lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
    lFirstCount := 0;
    lSecondCount := 0;
    lFirstBindingCount := 0;
    lNearestBindingCount := 0;
    lSecondBindingCount := 0;
    lUnknownBindingCount := 0;
    for lBinding in lFacts.Bindings do
      if SameText(lBinding.SelectorText, 'Child') and
        SameText(lBinding.UnitName, 'AUnit') and
        SameText(lBinding.RoutineName, 'RunA') then
      begin
        Inc(lFirstBindingCount);
        Assert.AreEqual(2, Integer(Length(lBinding.Selectors)));
        Assert.AreEqual('resolved', lBinding.Selectors[0].Status,
          'RunA parent: ' + lBinding.Selectors[0].ReasonCode);
        Assert.AreEqual('resolved', lBinding.Selectors[1].Status,
          'RunA child: ' + lBinding.Selectors[1].ReasonCode);
        Assert.AreEqual('TLeaf', lBinding.Selectors[1].TypeName);
        Assert.AreEqual('BaseUnit', lBinding.Selectors[1].TypeIdentity.UnitName);
        Assert.AreEqual('TLeaf', lBinding.Selectors[1].TypeIdentity.Name);
      end else if SameText(lBinding.SelectorText, 'Child') and
        SameText(lBinding.UnitName, 'BUnit') and
        SameText(lBinding.RoutineName, 'RunB') then
      begin
        Inc(lSecondBindingCount);
        Assert.AreEqual(2, Integer(Length(lBinding.Selectors)));
        Assert.AreEqual('resolved', lBinding.Selectors[0].Status,
          'RunB parent: ' + lBinding.Selectors[0].ReasonCode);
        Assert.AreEqual('resolved', lBinding.Selectors[1].Status,
          'RunB child: ' + lBinding.Selectors[1].ReasonCode);
        Assert.AreEqual('BaseUnit', lBinding.Selectors[1].TypeIdentity.UnitName);
        Assert.AreEqual('TLeaf', lBinding.Selectors[1].TypeIdentity.Name);
      end else if SameText(lBinding.SelectorText, 'Child') and
        SameText(lBinding.UnitName, 'AUnit') and
        SameText(lBinding.RoutineName, 'RunNearest') then
      begin
        Inc(lNearestBindingCount);
        Assert.AreEqual(3, Integer(Length(lBinding.Selectors)));
        if i = 0 then
        begin
          Assert.AreEqual('unsupported', lBinding.Selectors[1].Status);
          Assert.AreEqual('PARENT_SELECTOR_UNRESOLVED', lBinding.Selectors[1].ReasonCode);
          Assert.AreEqual('unsupported', lBinding.Selectors[2].Status);
        end else begin
          Assert.AreEqual('resolved', lBinding.Selectors[1].Status);
          Assert.AreEqual('TNearest', lBinding.Selectors[1].TypeName);
          Assert.AreEqual('resolved', lBinding.Selectors[2].Status);
          Assert.AreEqual('TWrongLeaf', lBinding.Selectors[2].TypeName);
          Assert.AreEqual('AUnit', lBinding.Selectors[2].TypeIdentity.UnitName);
          Assert.AreEqual('TWrongLeaf', lBinding.Selectors[2].TypeIdentity.Name);
        end;
      end else if SameText(lBinding.SelectorText, 'Child') and
        SameText(lBinding.UnitName, 'AUnit') and
        SameText(lBinding.RoutineName, 'RunUnknown') then
      begin
        Inc(lUnknownBindingCount);
        Assert.AreEqual(2, Integer(Length(lBinding.Selectors)));
        Assert.AreNotEqual('resolved', lBinding.Selectors[0].Status);
        Assert.AreNotEqual('resolved', lBinding.Selectors[1].Status,
          'An unknown parent must not turn the global Child namesake into a receiver.');
      end;
    Assert.AreEqual(1, lFirstBindingCount);
    Assert.AreEqual(1, lSecondBindingCount);
    Assert.AreEqual(1, lNearestBindingCount);
    Assert.AreEqual(1, lUnknownBindingCount);
    for lSymbol in lFacts.Symbols do
      if SameText(lSymbol.Name, 'Child') and
        SameText(lSymbol.SymbolClass, 'field') and
        SameText(lSymbol.OwnerName, 'TDerived') then
      begin
        Assert.AreEqual('BaseUnit', lSymbol.OwnerIdentity.UnitName);
        Assert.AreEqual('TBase', lSymbol.OwnerIdentity.Name);
        Assert.AreEqual(TPath.Combine(lRoot, 'BaseUnit.pas'),
          lSymbol.OwnerIdentity.SourceRange.FileName);
        if SameText(lSymbol.AccessOwnerIdentity.UnitName, 'AUnit') then
        begin
          Inc(lFirstCount);
          Assert.AreEqual(TPath.Combine(lRoot, 'AUnit.pas'),
            lSymbol.AccessOwnerIdentity.SourceRange.FileName);
        end else if SameText(lSymbol.AccessOwnerIdentity.UnitName, 'BUnit') then
        begin
          Inc(lSecondCount);
          Assert.AreEqual(TPath.Combine(lRoot, 'BUnit.pas'),
            lSymbol.AccessOwnerIdentity.SourceRange.FileName);
        end else
          Assert.Fail('Inherited projection has no proven access declaration.');
        Assert.AreEqual('TDerived', lSymbol.AccessOwnerIdentity.Name);
        Assert.IsTrue(lSymbol.AccessOwnerIdentity.DeclaredId.Value <> '');
      end;
    Assert.AreEqual(1, lFirstCount);
    Assert.AreEqual(1, lSecondCount);
  end;
end;

procedure TWithBinderTests.OneLineTypeDeclarationsDoNotOpenMemberBodies;
const
  cFakeOwners: array[0..8] of string = ('TShortDerived', 'TEmptyDerived', 'TEmpty',
    'TEmptyRec', 'TMeta', 'IForward', 'IEmpty', 'TOddVis', 'TLocalDerived');
  cOneLineTypes: array[0..9] of string = ('TShortDerived', 'TEmptyDerived', 'TEmpty',
    'TEmptyRec', 'TMeta', 'IEmpty', 'TWrongLeaf', 'TNearest', 'TOddVis', 'TAfterOdd');
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lFound: Boolean;
  lGlobalCount: Integer;
  lLines: TArray<string>;
  lMultiCount: Integer;
  lOptions: TDelphiSemanticApiOptions;
  lProjectPath: string;
  lRoot: string;
  lSymbol: TDelphiSemanticInventorySymbol;
  lTypeName: string;

  procedure AssertMember(const aName, aOwnerName, aTypeName: string; const aLine: Integer;
    const aExpectedCount: Integer = 1);
  var
    lCount: Integer;
    lMember: TDelphiSemanticInventorySymbol;
  begin
    lCount := 0;
    for lMember in lFacts.Symbols do
      if SameText(lMember.Name, aName) and SameText(lMember.SymbolClass, 'field') and
        SameText(lMember.OwnerName, aOwnerName) then
      begin
        Inc(lCount);
        Assert.AreEqual(aTypeName, lMember.TypeName, aOwnerName + '.' + aName + ' type');
        Assert.AreEqual(aLine, lMember.Line, aOwnerName + '.' + aName + ' line');
        Assert.AreEqual(Pos(aName, lLines[aLine - 1]), lMember.Column,
          aOwnerName + '.' + aName + ' column');
      end;
    Assert.AreEqual(aExpectedCount, lCount, 'Field count of ' + aOwnerName + '.' + aName);
  end;

  function CountFields(const aName, aOwnerName: string): Integer;
  var
    lMember: TDelphiSemanticInventorySymbol;
  begin
    Result := 0;
    for lMember in lFacts.Symbols do
      if SameText(lMember.Name, aName) and SameText(lMember.SymbolClass, 'field') and
        SameText(lMember.OwnerName, aOwnerName) then
        Inc(Result);
  end;

begin
  lRoot := WithBinderTempPath('one-line-types');
  TDirectory.CreateDirectory(lRoot);
  lProjectPath := TPath.Combine(lRoot, 'P.dproj');
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P;'#13#10'uses OneLineUnit in ''OneLineUnit.pas'';'#13#10 +
    'begin'#13#10'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(lProjectPath,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup><ItemGroup>' +
    '<DCCReference Include="OneLineUnit.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  // Every one-line form is followed by declarations that a still-open body would claim,
  // including a unit global that shares the inherited field name Child.
  lLines := [
    'unit OneLineUnit;',
    'interface',
    'type',
    '  TBase = class',
    '  public',
    '    Child: Integer;',
    '  end;',
    '  TForward = class;',
    '  TShortDerived = class(TBase);',
    '  TEmptyDerived = class(TBase) end;',
    '  TEmpty = class end;',
    '  TEmptyRec = record end;',
    '  TMeta = class of TBase;',
    '  IForward = interface;',
    '  IEmpty = interface end;',
    '  TWrongLeaf = record OtherValue: Integer; end;',
    '  TNearest = record Child: TWrongLeaf; end;',
    '  TOddVis = class(TBase) public Extra: Integer; end;',
    '  TAfterOdd = record Kept, Also: Integer; end;',
    '  TForward = class',
    '  public',
    '    Value: Integer;',
    '  end;',
    '  IForward = interface',
    '  end;',
    '  TMixed = record First: Integer;',
    '    Second: Integer;',
    '  end;',
    '  TMixedOdd = class(TBase) public Extra2: Integer;',
    '  end;',
    '  THintClass = class end deprecated;',
    '  THintRec = record HintValue: Integer; end platform;',
    '  THintMsg = class(TBase) end deprecated ''Use TBase'';',
    '  THintMulti = class end platform experimental;',
    '  TAfterHints = class',
    '  public',
    '    AfterValue: Integer;',
    '  end;',
    'var',
    '  Child: Integer;',
    'procedure RunLocal;',
    'implementation',
    'procedure RunLocal;',
    'type',
    '  TLocalDerived = class(TBase) end;',
    '  TLocalRec = record LocalValue: Integer; end;',
    '  TLocalMulti = record',
    '    MultiValue: Integer;',
    '  end;',
    'var',
    '  lRec: TLocalRec;',
    'begin',
    '  lRec.LocalValue := Child;',
    'end;',
    'end.'];
  TFile.WriteAllText(TPath.Combine(lRoot, 'OneLineUnit.pas'),
    string.Join(#13#10, lLines) + #13#10, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := lProjectPath;
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);

  lGlobalCount := 0;
  for lSymbol in lFacts.Symbols do
  begin
    if not SameText(lSymbol.UnitName, 'OneLineUnit') then
      Continue;
    if MatchText(lSymbol.SymbolClass, ['field', 'property', 'method', 'constant',
      'class-var']) then
    begin
      Assert.IsTrue((Pos('=', lSymbol.Name) = 0) and (Pos(' ', Trim(lSymbol.Name)) = 0),
        'A declaration line became member "' + lSymbol.Name + '" of ' + lSymbol.OwnerName);
      // Derived one-liners may only carry the inherited projection of TBase.Child, which
      // keeps the source line of the TBase declaration.
      if MatchText(lSymbol.OwnerName, cFakeOwners) then
        Assert.IsTrue(SameText(lSymbol.Name, 'Child') and (lSymbol.Line = 6),
          'Fake member ' + lSymbol.OwnerName + '.' + lSymbol.Name + ' at line ' +
          IntToStr(lSymbol.Line));
    end;
    if SameText(lSymbol.Name, 'Child') and (lSymbol.OwnerName = '') and
      SameText(lSymbol.SymbolClass, 'unit-global') then
    begin
      Inc(lGlobalCount);
      Assert.AreEqual(40, lSymbol.Line, 'Global Child line');
    end;
  end;
  Assert.AreEqual(1, lGlobalCount, 'The unit global Child must stay a unit global.');

  AssertMember('OtherValue', 'TWrongLeaf', 'Integer', 16);
  AssertMember('Child', 'TNearest', 'TWrongLeaf', 17);
  AssertMember('Kept', 'TAfterOdd', 'Integer', 19);
  AssertMember('Also', 'TAfterOdd', 'Integer', 19);
  AssertMember('Value', 'TForward', 'Integer', 22);
  // A routine-local record is reported by both the model and the text scanner, so the
  // one-line form must match the field count of the equivalent multi-line form.
  lMultiCount := CountFields('MultiValue', 'TLocalMulti');
  Assert.IsTrue(lMultiCount > 0, 'Expected the multi-line local record field.');
  AssertMember('LocalValue', 'TLocalRec', 'Integer', 46, lMultiCount);
  // A hint directive after the closing end still closes the type on its line, and the
  // following type keeps its own members.
  AssertMember('HintValue', 'THintRec', 'Integer', 32);
  AssertMember('AfterValue', 'TAfterHints', 'Integer', 37);
  for lSymbol in lFacts.Symbols do
    if SameText(lSymbol.SymbolClass, 'type-member') and
      SameText(lSymbol.UnitName, 'OneLineUnit') and
      MatchText(lSymbol.Name, ['THintClass', 'THintRec', 'THintMsg', 'THintMulti']) then
    begin
      Assert.AreEqual(lSymbol.Line, lSymbol.EndLine, lSymbol.Name + ' must end on its line.');
      Assert.AreEqual('', lSymbol.UnsupportedReason, lSymbol.Name + ' reason');
    end;
  for lSymbol in lFacts.Symbols do
    if MatchText(lSymbol.OwnerName, ['THintClass', 'THintRec', 'THintMsg', 'THintMulti']) and
      SameText(lSymbol.SymbolClass, 'field') then
      Assert.IsTrue(SameText(lSymbol.Name, 'HintValue') or
        (SameText(lSymbol.Name, 'Child') and (lSymbol.Line = 6)),
        'Fake member ' + lSymbol.OwnerName + '.' + lSymbol.Name);
  // A record whose first fields share the header line keeps its later body lines.
  AssertMember('First', 'TMixed', 'Integer', 26);
  AssertMember('Second', 'TMixed', 'Integer', 27);
  Assert.AreEqual(0, CountFields('Extra2', 'TMixedOdd'),
    'An unparsed header member must not be guessed.');
  lFound := False;
  for lSymbol in lFacts.Symbols do
    if SameText(lSymbol.SymbolClass, 'type-member') and
      SameText(lSymbol.UnitName, 'OneLineUnit') and
      (SameText(lSymbol.Name, 'TMixed') or SameText(lSymbol.Name, 'TMixedOdd')) then
    begin
      lFound := True;
      if SameText(lSymbol.Name, 'TMixed') then
      begin
        Assert.AreEqual(28, lSymbol.EndLine, 'TMixed end line');
        Assert.AreEqual('', lSymbol.UnsupportedReason, 'TMixed reason');
      end else
      begin
        Assert.AreEqual(30, lSymbol.EndLine, 'TMixedOdd end line');
        Assert.AreNotEqual('', lSymbol.UnsupportedReason, 'TMixedOdd must fail closed.');
      end;
    end;
  Assert.IsTrue(lFound, 'Expected the mixed record types.');

  for lTypeName in cOneLineTypes do
  begin
    lFound := False;
    for lSymbol in lFacts.Symbols do
      if SameText(lSymbol.Name, lTypeName) and SameText(lSymbol.SymbolClass, 'type-member') and
        SameText(lSymbol.UnitName, 'OneLineUnit') then
      begin
        lFound := True;
        Assert.AreEqual(lSymbol.Line, lSymbol.EndLine, lTypeName + ' must end on its own line.');
        // An inline body that is not plain fields stays unsupported instead of guessed.
        if SameText(lTypeName, 'TOddVis') then
          Assert.AreNotEqual('', lSymbol.UnsupportedReason, 'TOddVis must fail closed.')
        else
          Assert.AreEqual('', lSymbol.UnsupportedReason, lTypeName + ' reason');
      end;
    Assert.IsTrue(lFound, 'Expected type ' + lTypeName);
  end;
  for lSymbol in lFacts.Symbols do
    if SameText(lSymbol.Name, 'TBase') and SameText(lSymbol.SymbolClass, 'type-member') and
      SameText(lSymbol.UnitName, 'OneLineUnit') then
      Assert.AreEqual(7, lSymbol.EndLine, 'TBase body must still end at its end line.');
end;

procedure TWithBinderTests.IndexedPropertySelectorWithoutDereferenceStaysUnsupported;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lSource: string;
begin
  lPath := WithBinderTempPath('withbinder-indexed-property-regression.pas');
  lSource :=
    'unit WithBinderIndexedPropertyRegression;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TIndexedRecord = record' + sLineBreak +
    '    Name: string;' + sLineBreak +
    '  end;' + sLineBreak +
    '  TIndexedBox = class' + sLineBreak +
    '  private' + sLineBreak +
    '    function GetItem(const aIndex: Integer): TIndexedRecord;' + sLineBreak +
    '  public' + sLineBreak +
    '    property Items[const aIndex: Integer]: TIndexedRecord read GetItem; default;' +
    sLineBreak +
    '  end;' + sLineBreak +
    '  TScope = class' + sLineBreak +
    '  public' + sLineBreak +
    '    class procedure Run;' + sLineBreak +
    '  end;' + sLineBreak +
    'implementation' + sLineBreak +
    'function TIndexedBox.GetItem(const aIndex: Integer): TIndexedRecord;' + sLineBreak +
    'begin' + sLineBreak +
    '  Result.Name := '''';' + sLineBreak +
    'end;' + sLineBreak +
    'class procedure TScope.Run;' + sLineBreak +
    'var' + sLineBreak +
    '  lBox: TIndexedBox;' + sLineBreak +
    'begin' + sLineBreak +
    '  with lBox[0] do' + sLineBreak +
    '    Name := ''indexed property'';' + sLineBreak +
    'end;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.ASCII);
  try
    lOptions := Default(TDelphiSemanticModelOptions);
    lOptions.SourceFileName := lPath;
    lOptions.ProjectContextApplied := True;
    lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
    Assert.IsTrue(lModel.Success);

    lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

    Assert.AreEqual(1, Integer(Length(lBindings)));
    Assert.AreEqual('unsupported', lBindings[0].Selectors[0].Status);
    Assert.AreEqual('PROPERTY_SELECTOR_UNSUPPORTED', lBindings[0].Selectors[0].ReasonCode);
    Assert.AreEqual('', lBindings[0].Selectors[0].TypeName);
  finally
    if TFile.Exists(lPath) then
      TFile.Delete(lPath);
  end;
end;

procedure TWithBinderTests.MemberReferenceReportsRoutineScopeConflict;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lReference: TDelphiSemanticBoundReference;
  lSource: string;
begin
  lPath := WithBinderTempPath('withbinder-scope-conflict-regression.pas');
  lSource :=
    'unit WithBinderScopeConflictRegression;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TBox = class' + sLineBreak +
    '  public' + sLineBreak +
    '    procedure Flush;' + sLineBreak +
    '  end;' + sLineBreak +
    '  TScope = class' + sLineBreak +
    '  public' + sLineBreak +
    '    class procedure Run;' + sLineBreak +
    '  end;' + sLineBreak +
    'procedure Flush;' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure Flush;' + sLineBreak +
    'begin' + sLineBreak +
    'end;' + sLineBreak +
    'procedure TBox.Flush;' + sLineBreak +
    'begin' + sLineBreak +
    'end;' + sLineBreak +
    'class procedure TScope.Run;' + sLineBreak +
    'var' + sLineBreak +
    '  lBox: TBox;' + sLineBreak +
    'begin' + sLineBreak +
    '  with lBox do' + sLineBreak +
    '    Flush;' + sLineBreak +
    'end;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.ASCII);
  try
    lOptions := Default(TDelphiSemanticModelOptions);
    lOptions.SourceFileName := lPath;
    lOptions.ProjectContextApplied := True;
    lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
    Assert.IsTrue(lModel.Success);

    lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

    Assert.AreEqual(1, Integer(Length(lBindings)));
    for lReference in lBindings[0].References do
      if SameText(lReference.Name, 'Flush') and SameText(lReference.Classification, 'member') then
      begin
        Assert.AreEqual('routine', lReference.ScopeConflictKind);
        Assert.AreEqual('Flush', lReference.ScopeConflictName);
        Exit;
      end;
    Assert.Fail('Expected member-bound Flush reference.');
  finally
    if TFile.Exists(lPath) then
      TFile.Delete(lPath);
  end;
end;

procedure TWithBinderTests.UnresolvedReceiverShieldsOuterAndLexicalHomonyms;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lInspected: Integer;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lReference: TDelphiSemanticBoundReference;
begin
  // DS-705: the missing receiver can own Child or Count, so global and outer
  // homonyms do not establish a safe binding inside its WITH body.
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := WithBinderTempPath('unresolved-receiver-shielding.pas');
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit UnresolvedReceiverShielding;'#13#10 +
    'interface'#13#10 +
    'type'#13#10 +
    '  PChild = ^TChild;'#13#10 +
    '  TChild = record Count: Integer; end;'#13#10 +
    '  TOuter = record Count: Integer; Child: PChild; end;'#13#10 +
    'var'#13#10 +
    '  Outer: TOuter;'#13#10 +
    '  Child: PChild;'#13#10 +
    '  Count: Integer;'#13#10 +
    'implementation'#13#10 +
    'procedure RunNested;'#13#10 +
    'begin with Missing^ do with Child^ do Count := 1; end;'#13#10 +
    'procedure RunOuter;'#13#10 +
    'begin with Outer do with Missing^ do Count := 1; end;'#13#10 +
    'procedure RunLexical;'#13#10 +
    'begin with Missing^ do Count := 1; end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success, 'The unresolved receiver fixture must extract.');
  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  lInspected := 0;
  for lBinding in lBindings do
    if SameText(lBinding.RoutineName, 'RunNested') and
      SameText(lBinding.SelectorText, 'Child^') then
    begin
      Inc(lInspected);
      Assert.AreEqual(2, Integer(Length(lBinding.Selectors)));
      Assert.AreNotEqual('resolved', lBinding.Selectors[0].Status);
      Assert.AreNotEqual('resolved', lBinding.Selectors[1].Status,
        'The child must not acquire the global Child identity across an unresolved receiver.');
      Assert.AreEqual('', lBinding.Selectors[1].TypeIdentity.DeclaredId.Value);
    end else if (SameText(lBinding.RoutineName, 'RunOuter') or
      SameText(lBinding.RoutineName, 'RunLexical')) and
      SameText(lBinding.SelectorText, 'Missing^') then
    begin
      Inc(lInspected);
      Assert.IsTrue(HasAnyReference(lBinding, 'Count'));
      for lReference in lBinding.References do
        if SameText(lReference.Name, 'Count') then
        begin
          Assert.AreEqual('unsupported', lReference.Classification);
          Assert.AreEqual('SELECTOR_MEMBERS_UNVERIFIED', lReference.ReasonCode);
        end;
      Assert.IsFalse(HasReference(lBinding, 'Count', 'member'));
      Assert.IsFalse(HasReference(lBinding, 'Count', 'lexical'));
    end;
  Assert.AreEqual(3, lInspected, 'Inspect the nested selector, outer homonym and lexical homonym.');
end;

procedure TWithBinderTests.UnresolvedSelectorMarksBodyReferencesExternal;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  Assert.AreEqual('MissingReceiver', lBindings[2].Selectors[0].SelectorText);
  Assert.AreEqual('unresolved', lBindings[2].Selectors[0].Status);
  Assert.IsTrue(HasReference(lBindings[2], 'MissingMember', 'unsupported'));
  Assert.AreEqual('SELECTOR_MEMBERS_UNVERIFIED',
    ReasonOf(lBindings[2], 'MissingMember', 'unsupported'));
end;

procedure TWithBinderTests.NestedWithStatementsUseOuterReceiverStack;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lFoundOuterAfterInnerRange: Boolean;
  lModel: TDelphiSemanticUnitModel;
  lReference: TDelphiSemanticBoundReference;
begin
  lFoundOuterAfterInnerRange := False;
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  Assert.AreEqual(1, Integer(Length(lBindings[3].Selectors)));
  Assert.AreEqual('TFirstRecord', lBindings[3].Selectors[0].TypeName);
  Assert.IsFalse(HasAnyReference(lBindings[3], 'SecondOnly'));
  for lReference in lBindings[3].References do
    if SameText(lReference.Name, 'FirstOnly') and SameText(lReference.Classification, 'member') and
      (lReference.Line = 57) and (lReference.Column = 5) and (lReference.EndLine = 57) and
      (lReference.EndColumn = 13) then
      lFoundOuterAfterInnerRange := True;
  Assert.IsTrue(lFoundOuterAfterInnerRange, 'Expected outer reference after inner with to keep range.');
  Assert.AreEqual(2, Integer(Length(lBindings[4].Selectors)));
  Assert.AreEqual('TFirstRecord', lBindings[4].Selectors[0].TypeName);
  Assert.AreEqual('TSecondRecord', lBindings[4].Selectors[1].TypeName);
  Assert.AreEqual('TFirstRecord', ReceiverOf(lBindings[4], 'FirstOnly', 'member'));
  Assert.AreEqual('TSecondRecord', ReceiverOf(lBindings[4], 'SecondOnly', 'member'));
end;

procedure TWithBinderTests.NestedRoutineWithUsesParentRoutineScope;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  Assert.AreEqual('lOuterReceiver', lBindings[5].Selectors[0].SelectorText);
  Assert.AreEqual('resolved', lBindings[5].Selectors[0].Status);
  Assert.AreEqual('TFirstRecord', lBindings[5].Selectors[0].TypeName);
  Assert.IsTrue(HasReference(lBindings[5], 'FirstOnly', 'member'));
  Assert.IsTrue(HasReference(lBindings[5], 'lInnerValue', 'lexical'));
end;

procedure TWithBinderTests.SiblingRoutineLocalsDoNotLeakIntoNestedWith;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  Assert.AreEqual('lSiblingReceiver', lBindings[6].Selectors[0].SelectorText);
  Assert.AreEqual('unresolved', lBindings[6].Selectors[0].Status);
  Assert.IsTrue(HasReference(lBindings[6], 'FirstOnly', 'unsupported'));
  Assert.AreEqual('SELECTOR_MEMBERS_UNVERIFIED',
    ReasonOf(lBindings[6], 'FirstOnly', 'unsupported'));
end;

procedure TWithBinderTests.PlanningMetadataCountsLookupSourcesAndReasons;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  lBinding := lBindings[7];

  Assert.AreEqual('skipped', lBinding.Status);
  Assert.AreEqual('UNSUPPORTED_REFERENCE', lBinding.SkipReason);
  Assert.AreEqual(5, lBinding.MemberReferenceCount);
  Assert.AreEqual(2, lBinding.LexicalReferenceCount);
  Assert.AreEqual(3, lBinding.ExternalReferenceCount);
  Assert.AreEqual(1, lBinding.IntrinsicReferenceCount);
  Assert.AreEqual(3, lBinding.UnsupportedReferenceCount);
  Assert.AreEqual(1, lBinding.UnresolvedReferenceCount);
  Assert.AreEqual('receiver', LookupSourceOf(lBinding, 'FirstOnly', 'member'));
  Assert.AreEqual('lexical', LookupSourceOf(lBinding, 'lText', 'lexical'));
  Assert.AreEqual(2, CountReferences(lBinding, 'lText'));
  Assert.AreEqual('intrinsic', LookupSourceOf(lBinding, 'Length', 'intrinsic'));
  Assert.AreEqual('external', LookupSourceOf(lBinding, 'KnownExternalCall', 'external'));
  Assert.AreEqual('EXTERNAL_ROUTINE_CALL', ReasonOf(lBinding, 'KnownExternalCall', 'external'));
  Assert.AreEqual('UNKNOWN_ROUTINE_CALL', ReasonOf(lBinding, 'UnknownExternalCall', 'external'));
  Assert.AreEqual('CALL_SELECTOR_UNSUPPORTED', ReasonOf(lBinding, 'FirstOnly', 'unsupported'));
  Assert.AreEqual('INDEXED_SELECTOR_UNSUPPORTED', ReasonOf(lBinding, 'FirstOnly[0]', 'unsupported'));
  Assert.AreEqual('CALL_SELECTOR_UNSUPPORTED', ReasonOf(lBinding, 'TFirstRecord', 'unsupported'));
  Assert.AreEqual('NAME_NOT_FOUND', ReasonOf(lBinding, 'MissingPlanValue', 'unresolved'));
end;

procedure TWithBinderTests.ScopedDeclarationsMarkBindingSkipped;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  lBinding := lBindings[8];

  Assert.IsTrue(lBinding.HasScopedDeclaration);
  Assert.AreEqual('skipped', lBinding.Status);
  Assert.AreEqual('SCOPED_DECLARATION', lBinding.SkipReason);
end;

procedure TWithBinderTests.ControlCharacterLiteralsAreIgnored;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  lBinding := lBindings[7];

  Assert.AreEqual(6, CountReferences(lBinding, 'FirstOnly'));
  Assert.IsFalse(HasAnyReference(lBinding, '13'));
  Assert.IsFalse(HasAnyReference(lBinding, '10'));
end;

procedure TWithBinderTests.SafeBindingsArePlannedDirectReferences;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  lBinding := lBindings[1];

  Assert.AreEqual('planned', lBinding.Status);
  Assert.AreEqual('', lBinding.SkipReason);
  Assert.AreEqual(3, lBinding.MemberReferenceCount);
  Assert.AreEqual(0, lBinding.UnsupportedReferenceCount);
  Assert.AreEqual(0, lBinding.UnresolvedReferenceCount);
  Assert.AreEqual(0, lBinding.ExternalReferenceCount);
end;

procedure TWithBinderTests.SkipReasonsCoverExternalAndUnresolvedBranches;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  Assert.AreEqual('skipped', lBindings[6].Status);
  Assert.AreEqual('UNSUPPORTED_REFERENCE', lBindings[6].SkipReason);
  Assert.AreEqual('skipped', lBindings[9].Status);
  Assert.AreEqual('UNRESOLVED_REFERENCE', lBindings[9].SkipReason);
  Assert.IsTrue(HasReference(lBindings[9], 'MissingOnly', 'unresolved'));
end;

procedure TWithBinderTests.CastExpressionRolesRemainUnsupported;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  lBinding := lBindings[7];

  Assert.IsTrue(HasReference(lBinding, 'TFirstRecord', 'unsupported'));
  Assert.AreEqual('none', LookupSourceOf(lBinding, 'TFirstRecord', 'unsupported'));
  Assert.AreEqual('CALL_SELECTOR_UNSUPPORTED', ReasonOf(lBinding, 'TFirstRecord', 'unsupported'));
end;

procedure TWithBinderTests.InventoryExposesFileAwareSymbolsAndBindings;
var
  lFoundCallArgumentRange: Boolean;
  lFoundFirstOnlyRange: Boolean;
  lFoundRepeatedCallArgumentRange: Boolean;
  lInventory: TDelphiSemanticRemoveWithInventory;
  lModel: TDelphiSemanticUnitModel;
  lRangeDetails: string;
  lReference: TDelphiSemanticBoundReference;
begin
  lFoundCallArgumentRange := False;
  lFoundFirstOnlyRange := False;
  lFoundRepeatedCallArgumentRange := False;
  lRangeDetails := '';
  lModel := LoadModel;

  lInventory := TDelphiSemanticWithBinder.BuildInventory(lModel);

  Assert.AreEqual(lModel.FileName, lInventory.FileName);
  Assert.AreEqual('WithBinderUnit', lInventory.UnitName);
  Assert.IsTrue(HasInventorySymbol(lInventory, 'WithBinderUnit', 'unit', ''));
  Assert.IsTrue(HasInventorySymbol(lInventory, 'TFirstRecord', 'declaration', ''));
  Assert.IsTrue(HasInventorySymbol(lInventory, 'FirstOnly', 'member', ''));
  Assert.IsTrue(HasInventorySymbol(lInventory, 'RunWithBinder', 'routine', ''));
  Assert.IsTrue(HasInventorySymbol(lInventory, 'aParamValue', 'parameter', 'RunWithBinder'));
  Assert.IsTrue(HasInventorySymbol(lInventory, 'lFirst', 'local', 'RunWithBinder'));
  Assert.IsTrue(Length(lInventory.Bindings) > 0, 'Expected with bindings.');
  Assert.AreEqual(lModel.FileName, lInventory.Bindings[0].FileName);
  Assert.AreEqual('WithBinderUnit', lInventory.Bindings[0].UnitName);
  Assert.AreEqual('RunWithBinder', lInventory.Bindings[0].RoutineName);
  Assert.AreEqual(1, Integer(Length(lInventory.Bindings[0].Selectors)));
  Assert.AreEqual('lFirst', lInventory.Bindings[0].Selectors[0].SelectorText);
  for lReference in lInventory.Bindings[0].References do
    if SameText(lReference.Name, 'FirstOnly') and SameText(lReference.Classification, 'member') and
      (lReference.Line = 32) and (lReference.Column = 5) and (lReference.EndLine = 32) and
      (lReference.EndColumn = 13) then
      lFoundFirstOnlyRange := True;
  Assert.IsTrue(lFoundFirstOnlyRange, 'Expected exact source range for FirstOnly member reference.');
  for lReference in lInventory.Bindings[7].References do
  begin
    if SameText(lReference.Name, 'FirstOnly') then
      lRangeDetails := lRangeDetails + Format('%s:%d:%d-%d:%d ',
        [lReference.Classification, lReference.Line, lReference.Column, lReference.EndLine,
        lReference.EndColumn]);
    if SameText(lReference.Name, 'FirstOnly') and SameText(lReference.Classification, 'member') and
      (lReference.Line = 99) and (lReference.Column = 23) and (lReference.EndLine = 99) and
      (lReference.EndColumn = 31) then
      lFoundCallArgumentRange := True;
    if SameText(lReference.Name, 'FirstOnly') and SameText(lReference.Classification, 'member') and
      (lReference.Line = 100) and (lReference.Column = 23) and (lReference.EndLine = 100) and
      (lReference.EndColumn = 31) then
      lFoundRepeatedCallArgumentRange := True;
  end;
  Assert.IsTrue(lFoundCallArgumentRange, 'Expected exact source range for FirstOnly call argument. Actual: ' +
    lRangeDetails);
  Assert.IsTrue(lFoundRepeatedCallArgumentRange,
    'Expected exact source range for repeated FirstOnly call argument. Actual: ' + lRangeDetails);
end;

procedure TWithBinderTests.InventoryExposesDakPlannerSourceModelFacts;
var
  lInventory: TDelphiSemanticRemoveWithInventory;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lIndentedDetails: string;
  lProjectedBaseName: Boolean;
  lScanSymbol: TDelphiSemanticInventorySymbol;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  lProjectedBaseName := False;
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('WithBinder', 'SourceModelGoldenUnit.pas');
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);

  lInventory := TDelphiSemanticWithBinder.BuildInventory(lModel);
  lInventory.Symbols := TDelphiSemanticWithBinder.ExpandInventorySymbols(lInventory.Symbols);

  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'TGoldenVariant', 'type-member', '', lSymbol));
  Assert.AreEqual('record', lSymbol.TypeCategory);
  Assert.IsTrue(lSymbol.EndLine > lSymbol.Line, 'Expected declaration end range.');

  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'Mode', 'field', 'TGoldenVariant', lSymbol));
  Assert.AreEqual('Integer', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'MultiA', 'field', 'TGoldenVariant', lSymbol));
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'MultiB', 'field', 'TGoldenVariant', lSymbol));
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'RealValue', 'field', 'TGoldenVariant', lSymbol));
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'ExtraReal', 'field', 'TGoldenVariant', lSymbol));
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'HasReal', 'field', 'TGoldenVariant', lSymbol));
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'TextValue', 'field', 'TGoldenVariant', lSymbol));
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'Offset', 'field', 'TGoldenVariant', lSymbol));
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'Size', 'field', 'TGoldenVariant', lSymbol));
  Assert.IsFalse(TryFindInventorySymbol(lInventory, 'cGoldenVariantReal', 'field',
    'TGoldenVariant', lSymbol));
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'GoldenSplitGlobal', 'unit-global', '',
    lSymbol), 'Expected split unit-global declaration.');
  Assert.AreEqual('Integer', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'gisSkip', 'constant', '', lSymbol),
    'Expected unit-global anonymous enum value.');
  Assert.AreEqual('(gisRead, gisSkip)', lSymbol.TypeName);

  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'PGoldenRecord', 'type-member', '', lSymbol));
  Assert.AreEqual('^TGoldenRecord', lSymbol.TypeName);
  Assert.AreEqual('TGoldenRecord', lSymbol.RelatedTypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'TGoldenRecordAlias', 'type-member', '',
    lSymbol));
  Assert.AreEqual('TGoldenRecord', lSymbol.TypeName);
  Assert.AreEqual('TGoldenRecord', lSymbol.RelatedTypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'RecordName', 'field', 'TGoldenRecordAlias',
    lSymbol));
  Assert.AreEqual('TGoldenRecord', lSymbol.SourceOwnerType);

  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'Items', 'property', 'TGoldenDefaultList',
    lSymbol));
  Assert.IsTrue(lSymbol.IsDefault);
  Assert.IsTrue(lSymbol.IsIndexed);
  Assert.AreEqual(1, lSymbol.IndexParameterCount);
  Assert.AreEqual('PGoldenRecord', lSymbol.TypeName);

  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'lRecords', 'local', '', lSymbol));
  Assert.AreEqual('TArray<TGoldenRecord>', lSymbol.TypeName);
  Assert.AreEqual('TGoldenScope.Run', lSymbol.RoutineName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'lStaticRecordPtrs', 'local', '', lSymbol));
  Assert.AreEqual('array[1..2]ofPGoldenRecord', StringReplace(lSymbol.TypeName, ' ', '',
    [rfReplaceAll]));
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'TGoldenLocalRecord', 'type-member', '',
    lSymbol));
  Assert.AreEqual('record', lSymbol.TypeCategory);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'LocalName', 'field', 'TGoldenLocalRecord',
    lSymbol));
  Assert.AreEqual('string', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'LocalCount', 'field', 'TGoldenLocalRecord',
    lSymbol));
  Assert.AreEqual('Integer', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'lLocalRecord', 'local', '', lSymbol));
  Assert.AreEqual('TGoldenLocalRecord', lSymbol.TypeName);
  Assert.AreEqual('TGoldenScope.Run', lSymbol.RoutineName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'TGoldenScope.Run.lAnonymousLocal',
    'type-member', '', lSymbol));
  Assert.AreEqual('record', lSymbol.TypeCategory);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'LocalFlag', 'field',
    'TGoldenScope.Run.lAnonymousLocal', lSymbol));
  Assert.AreEqual('Boolean', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'LocalText', 'field',
    'TGoldenScope.Run.lAnonymousLocal', lSymbol));
  Assert.AreEqual('string', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'lAnonymousLocal', 'local', '', lSymbol));
  Assert.AreEqual('TGoldenScope.Run.lAnonymousLocal', lSymbol.TypeName);
  Assert.AreEqual('TGoldenScope.Run', lSymbol.RoutineName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'TGoldenScope.Run.lVariantLocal',
    'type-member', '', lSymbol));
  Assert.AreEqual('record', lSymbol.TypeCategory);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'Len', 'field',
    'TGoldenScope.Run.lVariantLocal', lSymbol));
  Assert.AreEqual('Byte', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'Kind', 'field',
    'TGoldenScope.Run.lVariantLocal', lSymbol));
  Assert.AreEqual('Integer', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'AsInteger', 'field',
    'TGoldenScope.Run.lVariantLocal', lSymbol));
  Assert.AreEqual('Integer', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'AsText', 'field',
    'TGoldenScope.Run.lVariantLocal', lSymbol));
  Assert.AreEqual('string', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'lVariantLocal', 'local', '', lSymbol));
  Assert.AreEqual('TGoldenScope.Run.lVariantLocal', lSymbol.TypeName);
  Assert.AreEqual('TGoldenScope.Run', lSymbol.RoutineName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'TGoldenLateLocalRecord', 'type-member', '',
    lSymbol));
  Assert.AreEqual('record', lSymbol.TypeCategory);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'LateName', 'field', 'TGoldenLateLocalRecord',
    lSymbol));
  Assert.AreEqual('string', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'lLateLocalRecord', 'local', '', lSymbol));
  Assert.AreEqual('TGoldenLateLocalRecord', lSymbol.TypeName);
  lIndentedDetails := '';
  for lScanSymbol in lInventory.Symbols do
    if ContainsText(lScanSymbol.Name, 'GoldenIndented') or ContainsText(lScanSymbol.TypeName,
      'GoldenIndented') then
      lIndentedDetails := lIndentedDetails + lScanSymbol.Name + ':' + lScanSymbol.SymbolClass + ':' +
        lScanSymbol.TypeName + ':' + lScanSymbol.OwnerType + '; ';
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'TGoldenIndentedState', 'type-member', '',
    lSymbol), 'Expected indented implementation type. Symbols=' + lIndentedDetails);
  Assert.AreEqual('record', lSymbol.TypeCategory);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'StateName', 'field',
    'TGoldenIndentedState', lSymbol), 'Expected indented implementation type field. Symbols=' +
    lIndentedDetails);
  Assert.AreEqual('string', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'GoldenIndentedState', 'unit-global', '',
    lSymbol), 'Expected indented implementation var. Symbols=' + lIndentedDetails);
  Assert.AreEqual('TGoldenIndentedState', lSymbol.TypeName);

  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'BaseName', 'field', 'TGoldenClass', lSymbol));
  Assert.AreEqual('TGoldenBase', lSymbol.SourceOwnerType);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'HelperTouch', 'method', 'TGoldenRecord',
    lSymbol));
  Assert.AreEqual('TGoldenRecordHelper', lSymbol.SourceOwnerType);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'Touch', 'method', 'TGoldenClass', lSymbol));
  Assert.IsTrue(lSymbol.IsOverride);
  for lScanSymbol in lInventory.Symbols do
    if SameText(lScanSymbol.Name, 'BaseName') and
      SameText(lScanSymbol.SymbolClass, 'current-class-member') and
      SameText(lScanSymbol.OwnerName, 'TGoldenClass') and
      SameText(lScanSymbol.RoutineName, 'TGoldenClass.Touch') then
      lProjectedBaseName := True;
  Assert.IsTrue(lProjectedBaseName);
end;

procedure TWithBinderTests.InventoryExpansionUsesIndexedOwnMemberLookup;
var
  lSourceText: string;
begin
  lSourceText := ReadRepoSource('src\DelphiSemantics.WithBinding.Inventory.pas');

  Assert.IsTrue(ContainsText(lSourceText, 'BuildInventoryOwnMemberKeys'),
    'Inventory expansion must build an indexed own-member lookup for large semantic inventories.');
  Assert.IsFalse(ContainsText(lSourceText, 'InventoryOwnerHasOwnMember(aSymbols'),
    'Inventory expansion must not scan every symbol for each related inherited member.');
end;

procedure TWithBinderTests.InventoryExpansionUsesStableRelatedMemberOwnerIndex;
var
  lExpansionEnd: Integer;
  lExpansionStart: Integer;
  lExpansionText: string;
  lSourceText: string;
begin
  lSourceText := ReadRepoSource('src\DelphiSemantics.WithBinding.Inventory.pas');
  lExpansionStart := Pos('procedure AddRelatedInventoryMemberSymbols', lSourceText);
  lExpansionEnd := Pos('procedure AddRelatedInventoryCurrentClassSymbols', lSourceText);
  lExpansionText := Copy(lSourceText, lExpansionStart, lExpansionEnd - lExpansionStart);

  Assert.IsTrue(ContainsText(lSourceText, 'BuildRelatedInventoryMemberRelations'),
    'Inventory expansion must index inherited/helper owner relations once for propagation.');
  Assert.IsFalse(ContainsText(lExpansionText, 'repeat'),
    'Inventory expansion must not rebuild related-member indexes in a repeat loop.');
end;

procedure TWithBinderTests.InventoryExpansionIndexesCurrentClassProjectionContexts;
var
  lExpansionEnd: Integer;
  lExpansionStart: Integer;
  lExpansionText: string;
  lSourceText: string;
begin
  lSourceText := ReadRepoSource('src\DelphiSemantics.WithBinding.Inventory.pas');
  lExpansionStart := Pos('procedure AddRelatedInventoryCurrentClassSymbols', lSourceText);
  lExpansionEnd := Pos('procedure AddExpandedExternalTypeSymbol', lSourceText);
  Assert.IsTrue((lExpansionStart > 0) and (lExpansionEnd > lExpansionStart),
    'Expected current-class expansion source section.');

  lExpansionText := Copy(lSourceText, lExpansionStart, lExpansionEnd - lExpansionStart);
  Assert.IsTrue(ContainsText(lExpansionText, 'lProjectedContextKeys'),
    'Current-class expansion must project each owner/routine context once.');
  Assert.IsTrue(ContainsText(lExpansionText,
    'lOwnerKey := lCurrentMember.UnitName + #31 + lCurrentMember.FileName'),
    'Current-class owner keys must include unit and file identity.');
  Assert.IsTrue(ContainsText(lExpansionText,
    'lProjectedContextKey := lOwnerKey + #31 + lCurrentMember.RoutineName'),
    'Current-class projection keys must include owner key plus routine identity.');
end;

procedure TWithBinderTests.InventoryExpansionScopesCurrentClassProjectionByUnit;
var
  lExpandedSymbols: TArray<TDelphiSemanticInventorySymbol>;
  lSymbols: TArray<TDelphiSemanticInventorySymbol>;

  function CountCurrentClassSymbol(const aName, aRoutineName,
    aUnitName: string): Integer;
  var
    lSymbol: TDelphiSemanticInventorySymbol;
  begin
    Result := 0;
    for lSymbol in lExpandedSymbols do
      if SameText(lSymbol.Name, aName) and
        SameText(lSymbol.SymbolClass, 'current-class-member') and
        SameText(lSymbol.RoutineName, aRoutineName) and
        SameText(lSymbol.UnitName, aUnitName) then
        Inc(Result);
  end;
begin
  SetLength(lSymbols, 8);

  lSymbols[0] := Default(TDelphiSemanticInventorySymbol);
  lSymbols[0].Name := 'UnitAOnly';
  lSymbols[0].SymbolClass := 'field';
  lSymbols[0].OwnerType := 'TDuplicate';
  lSymbols[0].UnitName := 'DuplicateA';
  lSymbols[0].FileName := 'DuplicateA.pas';

  lSymbols[1] := Default(TDelphiSemanticInventorySymbol);
  lSymbols[1].Name := 'UnitBOnly';
  lSymbols[1].SymbolClass := 'field';
  lSymbols[1].OwnerType := 'TDuplicate';
  lSymbols[1].UnitName := 'DuplicateB';
  lSymbols[1].FileName := 'DuplicateB.pas';

  lSymbols[2] := Default(TDelphiSemanticInventorySymbol);
  lSymbols[2].Name := 'ExistingA';
  lSymbols[2].SymbolClass := 'current-class-member';
  lSymbols[2].OwnerType := 'TDuplicate';
  lSymbols[2].RoutineName := 'RunA';
  lSymbols[2].UnitName := 'DuplicateA';
  lSymbols[2].FileName := 'DuplicateA.pas';

  lSymbols[3] := Default(TDelphiSemanticInventorySymbol);
  lSymbols[3].Name := 'ExistingB';
  lSymbols[3].SymbolClass := 'current-class-member';
  lSymbols[3].OwnerType := 'TDuplicate';
  lSymbols[3].RoutineName := 'RunB';
  lSymbols[3].UnitName := 'DuplicateB';
  lSymbols[3].FileName := 'DuplicateB.pas';

  lSymbols[4] := Default(TDelphiSemanticInventorySymbol);
  lSymbols[4].Name := 'UnitCOnly';
  lSymbols[4].SymbolClass := 'field';
  lSymbols[4].OwnerType := 'TDuplicate';
  lSymbols[4].UnitName := 'DuplicateC';
  lSymbols[4].FileName := 'DuplicateC.pas';

  lSymbols[5] := Default(TDelphiSemanticInventorySymbol);
  lSymbols[5].Name := 'UnitDOnly';
  lSymbols[5].SymbolClass := 'field';
  lSymbols[5].OwnerType := 'TDuplicate';
  lSymbols[5].UnitName := 'DuplicateD';
  lSymbols[5].FileName := 'DuplicateD.pas';

  lSymbols[6] := Default(TDelphiSemanticInventorySymbol);
  lSymbols[6].Name := 'ExistingC';
  lSymbols[6].SymbolClass := 'current-class-member';
  lSymbols[6].OwnerType := 'TDuplicate';
  lSymbols[6].RoutineName := 'RunShared';
  lSymbols[6].UnitName := 'DuplicateC';
  lSymbols[6].FileName := 'DuplicateC.pas';

  lSymbols[7] := Default(TDelphiSemanticInventorySymbol);
  lSymbols[7].Name := 'ExistingD';
  lSymbols[7].SymbolClass := 'current-class-member';
  lSymbols[7].OwnerType := 'TDuplicate';
  lSymbols[7].RoutineName := 'RunShared';
  lSymbols[7].UnitName := 'DuplicateD';
  lSymbols[7].FileName := 'DuplicateD.pas';

  lExpandedSymbols := TDelphiSemanticWithBinder.ExpandInventorySymbols(lSymbols);

  Assert.AreEqual(1, CountCurrentClassSymbol('UnitAOnly', 'RunA',
    'DuplicateA'));
  Assert.AreEqual(1, CountCurrentClassSymbol('UnitBOnly', 'RunB',
    'DuplicateB'));
  Assert.AreEqual(0, CountCurrentClassSymbol('UnitAOnly', 'RunB',
    'DuplicateA'), 'Unit A members must not project into Unit B routines.');
  Assert.AreEqual(0, CountCurrentClassSymbol('UnitBOnly', 'RunA',
    'DuplicateB'), 'Unit B members must not project into Unit A routines.');
  Assert.AreEqual(1, CountCurrentClassSymbol('UnitCOnly', 'RunShared',
    'DuplicateC'));
  Assert.AreEqual(1, CountCurrentClassSymbol('UnitDOnly', 'RunShared',
    'DuplicateD'));
end;

procedure TWithBinderTests.ReferenceScannerPreservesRepresentativeTokenShapes;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;

  procedure AssertReference(const aBinding: TDelphiSemanticWithBinding; const aName,
    aClassification: string; const aLine, aColumn, aEndLine, aEndColumn: Integer);
  var
    lDetails: string;
    lReference: TDelphiSemanticBoundReference;
  begin
    lDetails := '';
    for lReference in aBinding.References do
    begin
      lDetails := lDetails + Format('%s/%s@%d:%d-%d:%d ', [lReference.Name,
        lReference.Classification, lReference.Line, lReference.Column,
        lReference.EndLine, lReference.EndColumn]);
      if SameText(lReference.Name, aName) and
        SameText(lReference.Classification, aClassification) and
        (lReference.Line = aLine) and (lReference.Column = aColumn) and
        (lReference.EndLine = aEndLine) and (lReference.EndColumn = aEndColumn) then
        Exit;
    end;
    Assert.Fail(Format('Expected %s/%s at %d:%d-%d:%d. Actual: %s',
      [aName, aClassification, aLine, aColumn, aEndLine, aEndColumn, lDetails]));
  end;

begin
  lModel := LoadModel;
  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  AssertReference(lBindings[0], 'FirstOnly', 'member', 32, 5, 32, 13);
  AssertReference(lBindings[0], 'aParamValue', 'lexical', 32, 18, 32, 28);
  AssertReference(lBindings[0], 'lSecond.SecondOnly', 'unsupported', 34, 5, 34, 22);
  AssertReference(lBindings[0], 'FirstOnly[0]', 'unsupported', 38, 5, 38, 16);
  AssertReference(lBindings[7], 'KnownExternalCall', 'external', 99, 5, 99, 32);
  AssertReference(lBindings[7], 'FirstOnly', 'member', 99, 23, 99, 31);
end;

procedure TWithBinderTests.ReferenceBindingUsesManualIdentifierScanner;
var
  lArgumentScannerText: string;
  lArgumentStart: Integer;
  lBindEnd: Integer;
  lBindStart: Integer;
  lBindText: string;
  lSourceText: string;
begin
  lSourceText := ReadRepoSource('src\DelphiSemantics.WithBinding.pas');

  lArgumentStart := Pos('procedure AddArgumentReferences', lSourceText);
  lBindStart := Pos('function BindReferences', lSourceText);
  lBindEnd := Pos('function StatementContains', lSourceText);
  Assert.IsTrue((lArgumentStart > 0) and (lBindStart > lArgumentStart) and
    (lBindEnd > lBindStart), 'Expected reference binding source sections.');

  lArgumentScannerText := Copy(lSourceText, lArgumentStart, lBindStart - lArgumentStart);
  lBindText := Copy(lSourceText, lBindStart, lBindEnd - lBindStart);
  Assert.IsFalse(ContainsText(lArgumentScannerText, 'TRegEx.Match'),
    'Argument reference binding must use the manual identifier scanner.');
  Assert.IsFalse(ContainsText(lBindText, 'TRegEx.Match'),
    'Body reference binding must use the manual identifier scanner.');
end;

procedure TWithBinderTests.InventoryExpansionUsesOrdinalIgnoreCaseSymbolKeys;
var
  lKeyFunctionText: string;
  lSourceText: string;
begin
  lSourceText := ReadRepoSource('src\DelphiSemantics.WithBinding.Inventory.pas');
  lKeyFunctionText := Copy(lSourceText, Pos('function InventorySymbolKey', lSourceText), 900);

  Assert.IsTrue(ContainsText(lSourceText,
    'lKeys := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);'),
    'Inventory expansion symbol keys must use the Delphi ordinal-ignore-case comparer.');
  Assert.IsFalse(ContainsText(lKeyFunctionText, 'UpperCase('),
    'Inventory expansion must not allocate uppercase copies while building every symbol key.');
end;

procedure TWithBinderTests.InventoryExpansionDeduplicatesSymbolsCaseInsensitively;
var
  lExpandedSymbols: TArray<TDelphiSemanticInventorySymbol>;
  lLocalSymbolCount: Integer;
  lSymbol: TDelphiSemanticInventorySymbol;
  lSymbols: TArray<TDelphiSemanticInventorySymbol>;
begin
  SetLength(lSymbols, 2);
  lSymbols[0] := Default(TDelphiSemanticInventorySymbol);
  lSymbols[0].Name := 'LocalName';
  lSymbols[0].SymbolClass := 'local';
  lSymbols[0].TypeName := 'TRecord';
  lSymbols[0].RoutineName := 'TRunner.Run';
  lSymbols[0].UnitName := 'CaseUnit';
  lSymbols[0].FileName := 'CaseUnit.pas';
  lSymbols[0].Line := 10;
  lSymbols[0].Column := 5;

  lSymbols[1] := lSymbols[0];
  lSymbols[1].Name := 'localname';
  lSymbols[1].TypeName := 'trecord';
  lSymbols[1].RoutineName := 'trunner.run';
  lSymbols[1].UnitName := 'caseunit';
  lSymbols[1].FileName := 'caseunit.pas';

  lExpandedSymbols := TDelphiSemanticWithBinder.ExpandInventorySymbols(lSymbols);

  lLocalSymbolCount := 0;
  for lSymbol in lExpandedSymbols do
    if SameText(lSymbol.Name, 'LocalName') and SameText(lSymbol.SymbolClass, 'local') then
      Inc(lLocalSymbolCount);

  Assert.AreEqual(1, lLocalSymbolCount,
    'Inventory expansion must keep duplicate symbol identity case-insensitive.');
end;

procedure TWithBinderTests.AnonymousNestedRecordSelectorsUseSyntheticOwner;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lInventory: TDelphiSemanticRemoveWithInventory;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('WithBinder', 'NestedAnonymousWithUnit.pas');
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);

  lInventory := TDelphiSemanticWithBinder.BuildInventory(lModel);
  lInventory.Symbols := TDelphiSemanticWithBinder.ExpandInventorySymbols(lInventory.Symbols);
  Assert.IsFalse(TryFindInventorySymbol(lInventory, 'Version', 'field', 'DBF_File', lSymbol),
    'Expected nested anonymous fields not to be flattened onto the outer record.');
  Assert.IsFalse(TryFindInventorySymbol(lInventory, 'RecSize', 'field', 'DBF_File', lSymbol),
    'Expected nested anonymous fields not to be flattened onto the outer record.');

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  Assert.AreEqual(1, Integer(Length(lBindings)));
  Assert.AreEqual('DBF_File', lBindings[0].Selectors[0].TypeName);
  Assert.AreEqual('DBF_File.Struktur', lBindings[0].Selectors[1].TypeName);
  Assert.IsTrue(HasReference(lBindings[0], 'Version', 'member'));
  Assert.AreEqual('DBF_File.Struktur', ReceiverOf(lBindings[0], 'Version', 'member'));
  Assert.IsTrue(HasReference(lBindings[0], 'RecSize', 'member'));
end;

procedure TWithBinderTests.GlobalAnonymousRecordSelectorUsesSyntheticOwner;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lInventory: TDelphiSemanticRemoveWithInventory;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('WithBinder', 'GlobalAnonymousWithUnit.pas');
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);

  lInventory := TDelphiSemanticWithBinder.BuildInventory(lModel);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'ModuleError', 'unit-global', '',
    lSymbol));
  Assert.AreEqual('GlobalAnonymousWithUnit.ModuleError', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'LineNo', 'field',
    'GlobalAnonymousWithUnit.ModuleError', lSymbol));

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  Assert.AreEqual(1, Integer(Length(lBindings)));
  Assert.AreEqual('ModuleError', lBindings[0].Selectors[0].SelectorText);
  Assert.AreEqual('GlobalAnonymousWithUnit.ModuleError', lBindings[0].Selectors[0].TypeName);
  Assert.IsTrue(HasReference(lBindings[0], 'fc', 'member'));
  Assert.IsTrue(HasReference(lBindings[0], 'LineNo', 'member'));
  Assert.IsTrue(HasReference(lBindings[0], 'ErrorChar', 'member'));
  Assert.AreEqual('GlobalAnonymousWithUnit.ModuleError', ReceiverOf(lBindings[0], 'fc', 'member'));
end;

procedure TWithBinderTests.DefaultIndexedPropertyPointerSelectorDereferencesToRecord;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('WithBinder', 'DefaultPointerWithUnit.pas');
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  Assert.AreEqual(1, Integer(Length(lBindings)));
  Assert.AreEqual('lList[0]^', lBindings[0].Selectors[0].SelectorText);
  Assert.AreEqual('TDefaultRecord', lBindings[0].Selectors[0].TypeName);
  Assert.IsTrue(HasReference(lBindings[0], 'Value', 'member'));
  Assert.AreEqual('TDefaultRecord', ReceiverOf(lBindings[0], 'Value', 'member'));
end;

procedure TWithBinderTests.NestedParentDefaultIndexedPropertyPointerSelectorDereferencesToRecord;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lCount: Integer;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('WithBinder',
    'NestedParentDefaultPointerWithUnit.pas');
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  lCount := 0;
  for lBinding in lBindings do
    if SameText(lBinding.RoutineName, 'RunNested') and
      SameText(lBinding.SelectorText, 'Maske[i]^') then
    begin
      Inc(lCount);
      Assert.AreEqual(2, Integer(Length(lBinding.Selectors)));
      Assert.AreEqual('TDatFile', lBinding.Selectors[0].TypeName);
      Assert.AreEqual('NestedParentDefaultPointerWithUnit',
        lBinding.Selectors[0].TypeIdentity.UnitName);
      Assert.AreEqual('TDatFile', lBinding.Selectors[0].TypeIdentity.Name);
      Assert.IsTrue(lBinding.Selectors[0].TypeIdentity.DeclaredId.Value <> '');
      Assert.AreEqual('resolved', lBinding.Selectors[1].Status);
      Assert.AreEqual('TMaskEntry', lBinding.Selectors[1].TypeName);
      Assert.AreEqual('NestedParentDefaultPointerWithUnit',
        lBinding.Selectors[1].TypeIdentity.UnitName);
      Assert.AreEqual('TMaskEntry', lBinding.Selectors[1].TypeIdentity.Name);
      Assert.IsTrue(lBinding.Selectors[1].TypeIdentity.DeclaredId.Value <> '');
      Assert.IsTrue(HasReference(lBinding, 'Value', 'member'));
      Assert.AreEqual('TMaskEntry', ReceiverOf(lBinding, 'Value', 'member'));
    end;
  Assert.AreEqual(1, lCount);
end;

procedure TWithBinderTests.NestedParentIndexedSelectorPreservesPrecedenceAndSafety;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lDeclaration: TDelphiSemanticDeclaration;
  lDiagnostic: TDelphiSemanticModelDiagnostic;
  lFoundAmbiguous: Boolean;
  lFoundIncomplete: Boolean;
  lFallbackCount: Integer;
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
  lNearestCount: Integer;
  lOptions: TDelphiSemanticModelOptions;
  lShadowCount: Integer;
  lUnresolvedCount: Integer;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('WithBinder',
    'NestedParentDefaultPointerWithUnit.pas');
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  lShadowCount := 0;
  lNearestCount := 0;
  lFallbackCount := 0;
  lUnresolvedCount := 0;
  for lBinding in lBindings do
  begin
    if not SameText(lBinding.SelectorText, 'Maske[0]^') then
      Continue;
    if SameText(lBinding.RoutineName, 'RunShadow') then
    begin
      Inc(lShadowCount);
      Assert.AreEqual('TMaskEntry', lBinding.Selectors[1].TypeName);
      Assert.IsTrue(HasReference(lBinding, 'Value', 'member'));
    end else if SameText(lBinding.RoutineName, 'RunNearestParent') then
    begin
      Inc(lNearestCount);
      Assert.AreEqual(3, Integer(Length(lBinding.Selectors)));
      Assert.AreEqual('TAltEntry', lBinding.Selectors[2].TypeName);
      Assert.IsTrue(HasReference(lBinding, 'AltValue', 'member'));
    end else if SameText(lBinding.RoutineName, 'RunLexicalFallback') then
    begin
      Inc(lFallbackCount);
      Assert.AreEqual('TAltEntry', lBinding.Selectors[1].TypeName);
      Assert.IsTrue(HasReference(lBinding, 'AltValue', 'member'));
    end;
  end;
  for lBinding in lBindings do
    if SameText(lBinding.RoutineName, 'RunUnresolved') and
      SameText(lBinding.SelectorText, 'Missing[0]^') then
    begin
      Inc(lUnresolvedCount);
      Assert.AreEqual('unresolved', lBinding.Selectors[1].Status,
        'RunUnresolved selector status');
      Assert.AreEqual('NAME_NOT_FOUND', lBinding.Selectors[1].ReasonCode,
        'RunUnresolved selector reason');
      Assert.AreEqual('skipped', lBinding.Status,
        'RunUnresolved receiver shields outer member homonyms in raw binding facts');
      Assert.AreEqual('UNSUPPORTED_REFERENCE', lBinding.SkipReason);
    end;
  Assert.AreEqual(1, lShadowCount);
  Assert.AreEqual(1, lNearestCount);
  Assert.AreEqual(1, lFallbackCount);
  Assert.AreEqual(1, lUnresolvedCount);

  lFoundAmbiguous := False;
  for lMember in lModel.Members do
    if SameText(lMember.OwnerName, 'TDatFile') and
      SameText(lMember.Name, 'Maske') then
    begin
      lFoundAmbiguous := True;
      Break;
    end;
  Assert.IsTrue(lFoundAmbiguous);
  SetLength(lModel.Members, Length(lModel.Members) + 1);
  lModel.Members[High(lModel.Members)] := lMember;
  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  lFoundAmbiguous := False;
  for lBinding in lBindings do
    if SameText(lBinding.RoutineName, 'RunNested') and
      SameText(lBinding.SelectorText, 'Maske[i]^') then
    begin
      Assert.AreEqual('ambiguous', lBinding.Selectors[1].Status,
        'RunNested duplicate member selector status');
      Assert.AreEqual('MULTIPLE_MEMBER_CANDIDATES',
        lBinding.Selectors[1].ReasonCode,
        'RunNested duplicate member selector reason');
      Assert.AreEqual('skipped', lBinding.Status,
        'RunNested duplicate member raw body-reference status');
      lFoundAmbiguous := True;
    end;
  Assert.IsTrue(lFoundAmbiguous);
  SetLength(lModel.Members, Length(lModel.Members) - 1);

  lFoundIncomplete := False;
  for lDeclaration in lModel.Declarations do
    if SameText(lDeclaration.Name, 'TMaskEntry') and
      SameText(lDeclaration.Kind, 'type') and
      SameText(lDeclaration.TypeName, 'record') then
    begin
      lDiagnostic := Default(TDelphiSemanticModelDiagnostic);
      lDiagnostic.Code := 'MEMBERS_INCOMPLETE';
      lDiagnostic.FileName := lDeclaration.FileName;
      if lDiagnostic.FileName = '' then
        lDiagnostic.FileName := lModel.FileName;
      lDiagnostic.Line := lDeclaration.Line;
      SetLength(lModel.Diagnostics, Length(lModel.Diagnostics) + 1);
      lModel.Diagnostics[High(lModel.Diagnostics)] := lDiagnostic;
      lFoundIncomplete := True;
      Break;
    end;
  Assert.IsTrue(lFoundIncomplete);
  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  for lBinding in lBindings do
    if SameText(lBinding.RoutineName, 'RunNested') and
      SameText(lBinding.SelectorText, 'Maske[i]^') then
    begin
      Assert.AreEqual('resolved', lBinding.Selectors[1].Status,
        'RunNested injected incomplete-owner selector status');
      Assert.AreEqual('TMaskEntry', lBinding.Selectors[1].TypeName);
      Assert.AreEqual('skipped', lBinding.Status,
        'RunNested injected incomplete-owner binding status');
      Assert.AreEqual('MEMBERS_INCOMPLETE', lBinding.SkipReason,
        'RunNested injected incomplete-owner safety reason');
      Exit;
    end;
  Assert.Fail('Expected nested selector binding with incomplete owner.');
end;

procedure TWithBinderTests.NestedUnresolvedSelectorRefusesFinalRewrite;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindingCount: Integer;
  lEdit: TDelphiSemanticRemoveWithEdit;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticApiOptions;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
  lStatementCount: Integer;
  lTarget: TDelphiSemanticWithBinding;
begin
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := FixturePath('WithBinder',
    'NestedParentDefaultPointerWith.dproj');
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  lBindingCount := 0;
  lTarget := Default(TDelphiSemanticWithBinding);
  for lBinding in lFacts.Bindings do
    if SameText(ExtractFileName(lBinding.FileName),
      'NestedParentDefaultPointerWithUnit.pas') and
      SameText(lBinding.UnitName, 'NestedParentDefaultPointerWithUnit') and
      SameText(lBinding.RoutineName, 'RunUnresolved') and
      SameText(lBinding.SelectorText, 'Missing[0]^') then
    begin
      Inc(lBindingCount);
      lTarget := lBinding;
      Assert.AreEqual(2, Integer(Length(lBinding.Selectors)),
        'RunUnresolved project binding selector stack');
      Assert.AreEqual('unresolved', lBinding.Selectors[1].Status,
        'RunUnresolved project selector status');
      Assert.AreEqual('NAME_NOT_FOUND', lBinding.Selectors[1].ReasonCode,
        'RunUnresolved project selector reason');
    end;
  Assert.AreEqual(1, lBindingCount,
    'RunUnresolved must identify exactly one source binding');

  lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
  lStatementCount := 0;
  for lStatement in lPlan.FinalStatements do
    if SameText(ExtractFileName(lStatement.FileName),
      'NestedParentDefaultPointerWithUnit.pas') and
      SameText(lStatement.RoutineName, 'RunUnresolved') and
      (lStatement.Range.StartLine = lTarget.Line) and
      (lStatement.Range.StartColumn = lTarget.Column) then
    begin
      Inc(lStatementCount);
      Assert.AreEqual('skipped', lStatement.Status,
        'RunUnresolved final statement status');
      Assert.AreEqual('selector-type-not-resolved', lStatement.Reason,
        'RunUnresolved final selector refusal');
      Assert.AreEqual(0, Integer(Length(lStatement.Edits)),
        'RunUnresolved final statement edits');
      Assert.AreEqual(0, Integer(Length(lStatement.Temps)),
        'RunUnresolved final statement temps');
      for lEdit in lPlan.Edits do
        Assert.AreNotEqual(lStatement.StatementId, lEdit.StatementId,
          'RunUnresolved must have no plan edit');
    end;
  Assert.AreEqual(1, lStatementCount,
    'RunUnresolved must identify exactly one final source statement');
end;

procedure TWithBinderTests.NestedIndexedSelectorPreservesBoundTypeDeclaringUnit;
var
  lADeclaredId: string;
  lAMaskTypeCount: Integer;
  lAValueCount: Integer;
  lBDeclaredId: string;
  lBMaskTypeCount: Integer;
  lBAltValueCount: Integer;
  lBinding: TDelphiSemanticWithBinding;
  lBindingCount: Integer;
  lDeclaration: TDelphiSemanticDeclaration;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticApiOptions;
  lRepeatedCount: Integer;
begin
  lADeclaredId := '';
  lBDeclaredId := '';
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := FixturePath('WithBinder',
    'NestedParentDefaultPointerWith.dproj');
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  lAMaskTypeCount := 0;
  lAValueCount := 0;
  lBMaskTypeCount := 0;
  lBAltValueCount := 0;
  for lModel in lFacts.UnitModels do
  begin
    for lDeclaration in lModel.Declarations do
      if SameText(lDeclaration.Name, 'TMaskType') and
        SameText(lDeclaration.Kind, 'type') then
      begin
        if SameText(lModel.UnitName, 'NestedParentBoundTypeOwnerA') then
          Inc(lAMaskTypeCount)
        else if SameText(lModel.UnitName, 'NestedParentBoundTypeOwnerB') then
          Inc(lBMaskTypeCount);
      end;
    for lMember in lModel.Members do
    begin
      if SameText(lModel.UnitName, 'NestedParentBoundTypeOwnerA') and
        SameText(lMember.OwnerName, 'TMaskEntry') and
        SameText(lMember.Name, 'Value') then
        Inc(lAValueCount);
      if SameText(lModel.UnitName, 'NestedParentBoundTypeOwnerB') and
        SameText(lMember.OwnerName, 'TAltEntry') and
        SameText(lMember.Name, 'AltValue') then
        Inc(lBAltValueCount);
    end;
  end;
  Assert.AreEqual(1, lAMaskTypeCount,
    'Imported owner A must declare one TMaskType');
  Assert.AreEqual(1, lBMaskTypeCount,
    'Caller B must declare a colliding local TMaskType');
  Assert.AreEqual(1, lAValueCount,
    'Value must belong to A.TMaskEntry');
  Assert.AreEqual(1, lBAltValueCount,
    'AltValue must belong to B.TAltEntry');

  lBindingCount := 0;
  for lBinding in lFacts.Bindings do
    if SameText(ExtractFileName(lBinding.FileName),
      'NestedParentBoundTypeOwnerB.pas') and
      SameText(lBinding.UnitName, 'NestedParentBoundTypeOwnerB') and
      SameText(lBinding.RoutineName, 'RunImportedBoundType') and
      SameText(lBinding.SelectorText, 'Maske[0]^') then
    begin
      Inc(lBindingCount);
      Assert.AreEqual(2, Integer(Length(lBinding.Selectors)),
        'Imported nested selector must retain outer D');
      Assert.AreEqual('resolved', lBinding.Selectors[1].Status,
        'Imported A.Maske selector status');
      Assert.AreEqual('TMaskEntry', lBinding.Selectors[1].TypeName,
        'A.TDatFile.Maske must retain A.TMaskType despite caller B homonym');
      Assert.AreEqual('NestedParentBoundTypeOwnerA',
        lBinding.Selectors[1].TypeIdentity.UnitName);
      Assert.AreEqual('NestedParentBoundTypeOwnerA.pas',
        ExtractFileName(lBinding.Selectors[1].TypeIdentity.SourceRange.FileName));
      lADeclaredId := lBinding.Selectors[1].TypeIdentity.DeclaredId.Value;
      Assert.IsTrue(lADeclaredId <> '');
      Assert.IsTrue(HasReference(lBinding, 'Value', 'member'),
        'Value must bind to A.TMaskEntry member');
      Assert.AreEqual('TMaskEntry', ReceiverOf(lBinding, 'Value', 'member'),
        'Value receiver must retain A.TMaskEntry type');
    end;
  Assert.AreEqual(1, lBindingCount,
    'Expected one nested imported A.Maske binding in B');

  lRepeatedCount := 0;
  for lBinding in lFacts.Bindings do
    if SameText(lBinding.UnitName, 'NestedParentBoundTypeOwnerB') and
      (SameText(lBinding.RoutineName, 'RunLocalThenImported') or
      SameText(lBinding.RoutineName, 'RunImportedThenLocal')) and
      SameText(lBinding.SelectorText, 'Maske[0]^') then
    begin
      Inc(lRepeatedCount);
      Assert.AreEqual(2, Integer(Length(lBinding.Selectors)),
        'Repeated two-owner selector stack');
      if SameText(lBinding.Selectors[0].SelectorText, 'D') then
      begin
        Assert.AreEqual('TMaskEntry', lBinding.Selectors[1].TypeName,
          'Imported A receiver must retain A type in either order');
        Assert.AreEqual('NestedParentBoundTypeOwnerA',
          lBinding.Selectors[1].TypeIdentity.UnitName);
        Assert.IsTrue(HasReference(lBinding, 'Value', 'member'),
          'Imported A receiver must bind A.Value in either order');
      end else if SameText(lBinding.Selectors[0].SelectorText, 'L') then
      begin
        Assert.AreEqual('TAltEntry', lBinding.Selectors[1].TypeName,
          'Local B receiver must retain B type in either order');
        Assert.AreEqual('NestedParentBoundTypeOwnerB',
          lBinding.Selectors[1].TypeIdentity.UnitName);
        lBDeclaredId := lBinding.Selectors[1].TypeIdentity.DeclaredId.Value;
        Assert.IsTrue(lBDeclaredId <> '');
        Assert.IsTrue(HasReference(lBinding, 'AltValue', 'member'),
          'Local B receiver must bind B.AltValue in either order');
      end else
        Assert.Fail('Unexpected outer receiver in repeated two-owner case.');
    end;
  Assert.AreEqual(4, lRepeatedCount,
    'Both receiver orders must produce two distinct inner bindings');
  Assert.IsTrue((lADeclaredId <> '') and (lBDeclaredId <> '') and
    (lADeclaredId <> lBDeclaredId),
    'Same-name owner types in imported and caller units need distinct declarations.');
end;

procedure TWithBinderTests.HiddenCompleteReceiverIgnoresUnrelatedDiagnostics;
var
  i: Integer;
  lAliasDetails: string;
  lBinding: TDelphiSemanticWithBinding;
  lCount: Integer;
  lDeclaration: TDelphiSemanticDeclaration;
  lDeclarationFileName: string;
  lDiagnostic: TDelphiSemanticModelDiagnostic;
  lDiagnosticDetails: string;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lHiddenOwnerLine: Integer;
  lIdentityDetails: string;
  lModels: TArray<TDelphiSemanticUnitModel>;
begin
  lModels := LoadReceiverSafetyModels;
  lAliasDetails := '';
  lDiagnosticDetails := '';
  lHiddenOwnerLine := 0;
  Assert.AreEqual(1, Integer(Length(lModels[3].InterfaceUses)),
    'Caller imports only the intermediate owner');
  Assert.IsTrue(SameText(lModels[3].InterfaceUses[0], 'ReceiverSafetyOwner'),
    'Caller import must be the intermediate owner');
  for i := 0 to 3 do
    for lDeclaration in lModels[i].Declarations do
    begin
      lDeclarationFileName := lDeclaration.FileName;
      if lDeclarationFileName = '' then
        lDeclarationFileName := lModels[i].FileName;
      if (i = 0) and SameText(lDeclaration.Name, 'THiddenEntry') and
        SameText(lDeclaration.Kind, 'type') then
        lHiddenOwnerLine := lDeclaration.Line;
      if ((i = 0) and SameText(lDeclaration.Name, 'PHiddenEntry')) or
        ((i = 1) and SameText(lDeclaration.Name, 'TAliasPointer')) then
        lAliasDetails := lAliasDetails + Format('%s.%s=%s@%s:%d; ',
          [lModels[i].UnitName, lDeclaration.Name, lDeclaration.TypeName,
          ExtractFileName(lDeclarationFileName), lDeclaration.Line]);
      if ((i = 0) and SameText(lDeclaration.Name, 'TUnrelated')) or
        ((i = 2) and SameText(lDeclaration.Name, 'TOther')) or
        ((i = 3) and SameText(lDeclaration.Name, 'THiddenEntry')) then
      begin
        Assert.AreEqual('type', lDeclaration.Kind,
          lModels[i].UnitName + '.' + lDeclaration.Name + ' diagnostic owner kind');
        Assert.AreEqual('record', lDeclaration.TypeName,
          lModels[i].UnitName + '.' + lDeclaration.Name + ' diagnostic owner type');
        lDiagnosticDetails := lDiagnosticDetails + Format('%s.%s %s/%s@%s:%d; ',
          [lModels[i].UnitName, lDeclaration.Name, lDeclaration.Kind,
          lDeclaration.TypeName, ExtractFileName(lDeclarationFileName),
          lDeclaration.Line]);
        lDiagnostic := Default(TDelphiSemanticModelDiagnostic);
        lDiagnostic.Code := 'MEMBERS_INCOMPLETE';
        lDiagnostic.FileName := lModels[i].FileName;
        lDiagnostic.Line := lDeclaration.Line;
        SetLength(lModels[i].Diagnostics, Length(lModels[i].Diagnostics) + 1);
        lModels[i].Diagnostics[High(lModels[i].Diagnostics)] := lDiagnostic;
      end;
    end;
  Assert.IsTrue(lHiddenOwnerLine > 0, 'Hidden receiver declaration must have a line');
  Assert.AreEqual(1, Integer(Length(lModels[0].Diagnostics)),
    'Hidden unit has one unrelated diagnostic');
  Assert.AreEqual(1, Integer(Length(lModels[2].Diagnostics)),
    'Intermediate owner has one unrelated diagnostic');
  Assert.AreEqual(1, Integer(Length(lModels[3].Diagnostics)),
    'Caller homonym has one unrelated diagnostic');
  lFacts := TDelphiSemanticWithBinder.BindProject('', nil, lModels);
  lCount := 0;
  for lBinding in lFacts.Bindings do
    if SameText(lBinding.UnitName, 'ReceiverSafetyCaller') and
      SameText(lBinding.SelectorText, 'Item^') then
    begin
      Inc(lCount);
      Assert.AreEqual(2, Integer(Length(lBinding.Selectors)),
        'Nested selector keeps its parent');
      lIdentityDetails := Format(
        'parent=%s.%s id=%s source=%s:%d; receiver=%s.%s id=%s source=%s:%d; aliases=%s; diagnostics=%s',
        [lBinding.Selectors[0].TypeIdentity.UnitName,
        lBinding.Selectors[0].TypeIdentity.Name,
        lBinding.Selectors[0].TypeIdentity.DeclaredId.Value,
        ExtractFileName(lBinding.Selectors[0].TypeIdentity.SourceRange.FileName),
        lBinding.Selectors[0].TypeIdentity.SourceRange.Line,
        lBinding.Selectors[1].TypeIdentity.UnitName,
        lBinding.Selectors[1].TypeIdentity.Name,
        lBinding.Selectors[1].TypeIdentity.DeclaredId.Value,
        ExtractFileName(lBinding.Selectors[1].TypeIdentity.SourceRange.FileName),
        lBinding.Selectors[1].TypeIdentity.SourceRange.Line,
        lAliasDetails, lDiagnosticDetails]);
      Assert.AreEqual('resolved', lBinding.Selectors[1].Status);
      Assert.AreEqual('THiddenEntry', lBinding.Selectors[1].TypeName);
      Assert.AreEqual('ReceiverSafetyOwner',
        lBinding.Selectors[0].TypeIdentity.UnitName, lIdentityDetails);
      Assert.AreEqual('ReceiverSafetyHidden',
        lBinding.Selectors[1].TypeIdentity.UnitName, lIdentityDetails);
      Assert.AreEqual('THiddenEntry',
        lBinding.Selectors[1].TypeIdentity.Name, lIdentityDetails);
      Assert.AreEqual(lHiddenOwnerLine,
        lBinding.Selectors[1].TypeIdentity.SourceRange.Line, lIdentityDetails);
      Assert.IsTrue(SameText(lModels[0].FileName,
        lBinding.Selectors[1].TypeIdentity.SourceRange.FileName), lIdentityDetails);
      Assert.IsNotEmpty(lBinding.Selectors[1].TypeIdentity.DeclaredId.Value,
        lIdentityDetails);
      Assert.AreNotEqual('MEMBERS_INCOMPLETE', lBinding.SkipReason,
        'Complete hidden receiver must ignore unrelated diagnostics. ' +
        lIdentityDetails);
      Assert.AreNotEqual('MEMBERS_UNVERIFIED', lBinding.SkipReason,
        'No hidden owner has unverified members');
    end;
  Assert.AreEqual(1, lCount, 'Expected one nested hidden receiver');
end;

procedure TWithBinderTests.AmbiguousFinalReceiverTypeFailsClosed;
var
  i: Integer;
  j: Integer;
  lBinding: TDelphiSemanticWithBinding;
  lBindingCount: Integer;
  lDeclaration: TDelphiSemanticDeclaration;
  lDiagnostic: TDelphiSemanticModelDiagnostic;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lResultCount: Integer;
  lTemplate: TDelphiSemanticDeclaration;
  lTemplateFound: Boolean;
  lValueCount: Integer;
  lWithCount: Integer;
begin
  lModels := LoadReceiverSafetyModels;
  lTemplate := Default(TDelphiSemanticDeclaration);
  lTemplateFound := False;
  for lDeclaration in lModels[0].Declarations do
    if SameText(lDeclaration.Name, 'THiddenEntry') and
      SameText(lDeclaration.Kind, 'type') then
    begin
      Assert.IsFalse(lTemplateFound, 'Expected one parsed hidden record type');
      lTemplate := lDeclaration;
      lTemplateFound := True;
    end;
  Assert.IsTrue(lTemplateFound, 'Hidden record type must come from the parsed fixture');
  Assert.AreEqual('record', lTemplate.TypeName);
  Assert.AreEqual('unit', lTemplate.ScopeKind);
  Assert.AreEqual('interface', lTemplate.SectionKind);
  Assert.AreEqual(LowerCase(lModels[0].UnitName), lTemplate.OwnerScopeId);
  Assert.IsNotEmpty(lTemplate.SymbolId);
  for i := 0 to 1 do
  begin
    j := Length(lModels[0].Declarations);
    SetLength(lModels[0].Declarations, j + 1);
    lModels[0].Declarations[j] := lTemplate;
    lModels[0].Declarations[j].Name := 'TResult';
    lModels[0].Declarations[j].Line := lTemplate.Line + 20 + i;
    lModels[0].Declarations[j].Offset := lTemplate.Offset + 200 + i * 10;
    lModels[0].Declarations[j].EndOffset := lTemplate.EndOffset + 200 + i * 10;
    lModels[0].Declarations[j].SymbolId := lTemplate.SymbolId + ':result-' + IntToStr(i);
  end;
  lResultCount := 0;
  for lDeclaration in lModels[0].Declarations do
    if SameText(lDeclaration.Name, 'TResult') and
      SameText(lDeclaration.ScopeKind, 'unit') and
      SameText(lDeclaration.SectionKind, 'interface') then
      Inc(lResultCount);
  Assert.AreEqual(2, lResultCount,
    'Two exported declarations share the final qualified type name');
  Assert.AreNotEqual(lModels[0].Declarations[High(lModels[0].Declarations) - 1].SymbolId,
    lModels[0].Declarations[High(lModels[0].Declarations)].SymbolId);
  lValueCount := 0;
  for i := 0 to High(lModels[0].Members) do
    if SameText(lModels[0].Members[i].OwnerName, 'THiddenEntry') and
      SameText(lModels[0].Members[i].Name, 'Value') then
    begin
      Inc(lValueCount);
      lModels[0].Members[i].TypeName := 'TResult';
    end;
  Assert.AreEqual(1, lValueCount, 'Mutated member must be the parsed hidden field');
  lWithCount := 0;
  for i := 0 to High(lModels[3].WithStatements) do
    if SameText(lModels[3].WithStatements[i].SelectorText, 'Item^') then
    begin
      Inc(lWithCount);
      lModels[3].WithStatements[i].SelectorText := 'Item^.Value';
    end;
  Assert.AreEqual(1, lWithCount, 'Mutated selector must be the parsed nested with');
  for i := 0 to 3 do
    for lDeclaration in lModels[i].Declarations do
      if ((i = 0) and SameText(lDeclaration.Name, 'TUnrelated')) or
        ((i = 2) and SameText(lDeclaration.Name, 'TOther')) or
        ((i = 3) and SameText(lDeclaration.Name, 'THiddenEntry')) then
      begin
        Assert.AreEqual('type', lDeclaration.Kind);
        Assert.AreEqual('record', lDeclaration.TypeName);
        lDiagnostic := Default(TDelphiSemanticModelDiagnostic);
        lDiagnostic.Code := 'MEMBERS_INCOMPLETE';
        lDiagnostic.FileName := lModels[i].FileName;
        lDiagnostic.Line := lDeclaration.Line;
        j := Length(lModels[i].Diagnostics);
        SetLength(lModels[i].Diagnostics, j + 1);
        lModels[i].Diagnostics[j] := lDiagnostic;
      end;
  Assert.AreEqual(1, Integer(Length(lModels[0].Diagnostics)));
  Assert.AreEqual(1, Integer(Length(lModels[2].Diagnostics)));
  Assert.AreEqual(1, Integer(Length(lModels[3].Diagnostics)));
  lFacts := TDelphiSemanticWithBinder.BindProject('', nil, lModels);
  lBindingCount := 0;
  for lBinding in lFacts.Bindings do
    if SameText(lBinding.UnitName, 'ReceiverSafetyCaller') and
      SameText(lBinding.SelectorText, 'Item^.Value') then
    begin
      Inc(lBindingCount);
      Assert.AreEqual(2, Integer(Length(lBinding.Selectors)));
      Assert.AreEqual('ReceiverSafetyOwner',
        lBinding.Selectors[0].TypeIdentity.UnitName);
      Assert.AreEqual('resolved', lBinding.Selectors[1].Status);
      Assert.AreEqual('TResult', lBinding.Selectors[1].TypeName);
      Assert.AreEqual('', lBinding.Selectors[1].TypeIdentity.UnitName,
        'Ambiguous exported final type must not acquire a unit identity');
      Assert.AreEqual('', lBinding.Selectors[1].TypeIdentity.DeclaredId.Value,
        'Ambiguous exported final type must not acquire one declared ID');
      Assert.AreEqual('MEMBERS_INCOMPLETE', lBinding.SkipReason,
        'Ambiguous final receiver must refuse member-safety lineage');
    end;
  Assert.AreEqual(1, lBindingCount, 'Expected one mutated nested receiver');
end;

procedure TWithBinderTests.HiddenReceiverExactOwnerDiagnosticsRefuse;
var
  lBinding: TDelphiSemanticWithBinding;
  lDeclaration: TDelphiSemanticDeclaration;
  lDiagnostic: TDelphiSemanticModelDiagnostic;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lFound: Boolean;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lOwnerLine: Integer;
  lReason: string;
begin
  lModels := LoadReceiverSafetyModels;
  lOwnerLine := 0;
  for lDeclaration in lModels[0].Declarations do
    if SameText(lDeclaration.Name, 'THiddenEntry') and
      SameText(lDeclaration.Kind, 'type') then
      lOwnerLine := lDeclaration.Line;
  Assert.IsTrue(lOwnerLine > 0, 'Hidden receiver declaration must be source backed');
  for lReason in ['MEMBERS_INCOMPLETE', 'MEMBERS_UNVERIFIED'] do
  begin
    lDiagnostic := Default(TDelphiSemanticModelDiagnostic);
    lDiagnostic.Code := lReason;
    lDiagnostic.FileName := lModels[0].FileName;
    if SameText(lReason, 'MEMBERS_INCOMPLETE') then
      lDiagnostic.Line := lOwnerLine;
    lModels[0].Diagnostics := [lDiagnostic];
    lFacts := TDelphiSemanticWithBinder.BindProject('', nil, lModels);
    lFound := False;
    for lBinding in lFacts.Bindings do
      if SameText(lBinding.UnitName, 'ReceiverSafetyCaller') and
        SameText(lBinding.SelectorText, 'Item^') then
      begin
        lFound := True;
        Assert.AreEqual('resolved', lBinding.Selectors[1].Status);
        Assert.AreEqual(lReason, lBinding.SkipReason,
          'Exact hidden owner diagnostic must refuse the binding');
      end;
    Assert.IsTrue(lFound, 'Expected one nested hidden receiver');
  end;
end;

procedure TWithBinderTests.BareImportedReceiverUsesActualOwnerForSafety;
var
  lBinding: TDelphiSemanticWithBinding;
  lDeclaration: TDelphiSemanticDeclaration;
  lDiagnostic: TDelphiSemanticModelDiagnostic;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lFound: Boolean;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lOwnerLine: Integer;
  lReason: string;
begin
  lModels := LoadBareReceiverSafetyModels;
  Assert.AreEqual(1, Integer(Length(lModels[2].InterfaceUses)),
    'Caller imports only the variable owner');
  Assert.IsTrue(SameText(lModels[2].InterfaceUses[0], 'ReceiverSafetyBareOwner'));
  lOwnerLine := 0;
  for lDeclaration in lModels[0].Declarations do
    if SameText(lDeclaration.Name, 'THiddenEntry') and
      SameText(lDeclaration.Kind, 'type') then
      lOwnerLine := lDeclaration.Line;
  Assert.IsTrue(lOwnerLine > 0, 'Hidden receiver declaration must be source backed');
  for lReason in ['MEMBERS_INCOMPLETE', 'MEMBERS_UNVERIFIED'] do
  begin
    lDiagnostic := Default(TDelphiSemanticModelDiagnostic);
    lDiagnostic.Code := lReason;
    lDiagnostic.FileName := lModels[0].FileName;
    if SameText(lReason, 'MEMBERS_INCOMPLETE') then
      lDiagnostic.Line := lOwnerLine;
    lModels[0].Diagnostics := [lDiagnostic];
    lFacts := TDelphiSemanticWithBinder.BindProject('', nil, lModels);
    lFound := False;
    for lBinding in lFacts.Bindings do
      if SameText(lBinding.UnitName, 'ReceiverSafetyBareCaller') and
        SameText(lBinding.SelectorText, 'G') then
      begin
        lFound := True;
        Assert.AreEqual('resolved', lBinding.Selectors[0].Status);
        Assert.AreEqual('THiddenEntry', lBinding.Selectors[0].TypeName);
        Assert.AreEqual(lReason, lBinding.SkipReason,
          'Bare imported receiver must refuse exact hidden owner diagnostic');
      end;
    Assert.IsTrue(lFound, 'Expected bare imported G binding');
  end;
  lModels[0].Diagnostics := nil;
  for lDeclaration in lModels[2].Declarations do
    if SameText(lDeclaration.Name, 'THiddenEntry') and
      SameText(lDeclaration.Kind, 'type') then
    begin
      lDiagnostic := Default(TDelphiSemanticModelDiagnostic);
      lDiagnostic.Code := 'MEMBERS_INCOMPLETE';
      lDiagnostic.FileName := lModels[2].FileName;
      lDiagnostic.Line := lDeclaration.Line;
      lModels[2].Diagnostics := [lDiagnostic];
    end;
  Assert.AreEqual(1, Integer(Length(lModels[2].Diagnostics)),
    'Caller homonym diagnostic must be source backed');
  lFacts := TDelphiSemanticWithBinder.BindProject('', nil, lModels);
  lFound := False;
  for lBinding in lFacts.Bindings do
    if SameText(lBinding.UnitName, 'ReceiverSafetyBareCaller') and
      SameText(lBinding.SelectorText, 'G') then
    begin
      lFound := True;
      Assert.AreNotEqual('MEMBERS_INCOMPLETE', lBinding.SkipReason,
        'Caller homonym diagnostic cannot refuse imported G');
    end;
  Assert.IsTrue(lFound, 'Expected bare imported G binding');
end;

procedure TWithBinderTests.BareImportedReceiverWithoutVisibleOwnerIsRefused;
var
  lBinding: TDelphiSemanticWithBinding;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lFound: Boolean;
  lModels: TArray<TDelphiSemanticUnitModel>;
begin
  lModels := LoadBareReceiverSafetyModels;
  lModels[2].InterfaceUses := nil;
  Assert.AreEqual(0, Integer(Length(lModels[2].InterfaceUses)));
  lFacts := TDelphiSemanticWithBinder.BindProject('', nil, lModels);
  lFound := False;
  for lBinding in lFacts.Bindings do
    if SameText(lBinding.UnitName, 'ReceiverSafetyBareCaller') and
      SameText(lBinding.SelectorText, 'G') then
    begin
      lFound := True;
      Assert.AreEqual('unresolved', lBinding.Selectors[0].Status,
        'Indexed G without a visible declaring unit must not bind');
      Assert.AreEqual('SELECTOR_TYPE_NOT_RESOLVED',
        lBinding.Selectors[0].ReasonCode);
      Assert.AreNotEqual('', lBinding.SkipReason,
        'Missing receiver provenance must refuse the binding without diagnostics');
    end;
  Assert.IsTrue(lFound, 'Expected bare imported G binding');
end;

procedure TWithBinderTests.RoutineTypeHomonymCannotSupplyReceiverMember(const aShape: string);
var
  lRoot, lReceiver, lGlobals, lBody: string;
  lOptions: TDelphiSemanticApiOptions;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lBinding: TDelphiSemanticWithBinding;
  lReference: TDelphiSemanticBoundReference;
  lPlan, lSnapshotPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
  lFound: Boolean;
  i: Integer;
begin
  lRoot := WithBinderTempPath('routine-type-homonym-' + aShape);
  TDirectory.CreateDirectory(lRoot);
  lGlobals := '';
  lReceiver := 'type TRec = ControlUnit.TRec;'#13#10'var R: TRec;'#13#10;
  lBody := 'Count := Count + 1';
  if aShape = 'direct' then
  begin
    lGlobals := 'var R: TRec;'#13#10'  Count: Integer;'#13#10;
    lReceiver := '';
    lBody := 'Other := Count';
  end;
  TFile.WriteAllText(TPath.Combine(lRoot, 'ControlUnit.pas'),
    'unit ControlUnit;'#13#10'interface'#13#10'type'#13#10 +
    '  TRec = record Other: Integer; end;'#13#10 + lGlobals +
    'implementation'#13#10'procedure X;'#13#10'type'#13#10 +
    '  TRec = record Count: Integer; end;'#13#10'var L: TRec;'#13#10 +
    'begin'#13#10'  L.Count := 1;'#13#10'end;'#13#10'end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
    'unit Unit1;'#13#10'interface'#13#10'uses ControlUnit;'#13#10 + lReceiver +
    'implementation'#13#10'procedure Run;'#13#10'begin'#13#10 +
    '  with R do ' + lBody + ';'#13#10'end;'#13#10'end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P; uses Unit1, ControlUnit; begin end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dproj'),
    '<Project><PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="Unit1.pas"/>' +
    '<DCCReference Include="ControlUnit.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.Combine(lRoot, 'P.dproj');
  lOptions.Cache.SqliteCacheFileName := TPath.Combine(lRoot, 'cache.sqlite');
  for i := 0 to 1 do
  begin
    lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
    lFound := False;
    for lBinding in lFacts.Bindings do
      if SameText(lBinding.UnitName, 'Unit1') then
        for lReference in lBinding.References do
          if SameText(lReference.Name, 'Count') then
          begin
            lFound := True;
            Assert.AreNotEqual('member', lReference.Classification,
              'A routine-local declaration cannot supply a unit-level receiver member.');
            if aShape = 'cross' then
              Assert.AreEqual('unresolved', lReference.Classification, lReference.ReasonCode)
            else
              Assert.AreEqual('lexical', lReference.Classification, lReference.ReasonCode);
          end;
    Assert.IsTrue(lFound);
    lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
    lSnapshotPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWithCompatibilitySnapshot(lFacts);
    lFound := False;
    for lStatement in lPlan.FinalStatements do
      if SameText(ExtractFileName(lStatement.FileName), 'Unit1.pas') then
      begin
        lFound := True;
        Assert.IsFalse(ContainsText(lStatement.ReplacementText, '.Count'));
        if aShape = 'cross' then
        begin
          Assert.AreEqual('skipped', lStatement.Status);
          Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
          Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
          Assert.AreEqual('', lStatement.ReplacementText);
        end else begin
          Assert.AreEqual('skipped', lStatement.Status);
          Assert.AreEqual('receiver-member-owner-conflict', lStatement.Reason);
          Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
          Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
          Assert.AreEqual('', lStatement.ReplacementText);
        end;
      end;
    Assert.IsTrue(lFound);
    for lStatement in lSnapshotPlan.FinalStatements do
      if SameText(ExtractFileName(lStatement.FileName), 'Unit1.pas') then
      begin
        Assert.IsFalse(ContainsText(lStatement.ReplacementText, '.Count'));
        if aShape = 'cross' then
        begin
          Assert.AreEqual('skipped', lStatement.Status);
          Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
        end else
          Assert.AreEqual('skipped', lStatement.Status, lStatement.Reason);
      end;
  end;
end;

procedure TWithBinderTests.UnindexedHelperCacheAndLostFacts(const aMode: string);
var
  lOptions: TDelphiSemanticModelOptions;
  lModel: TDelphiSemanticUnitModel;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lObject: TJSONObject;
  lValue: TJSONPair;
  lBinding: TDelphiSemanticWithBinding;
  lReference: TDelphiSemanticBoundReference;
  lCount: Integer;
  lExpected: string;
  lSource: string;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := WithBinderTempPath('helper-cache-' + aMode + '.pas');
  lSource :=
    'unit HelperCache;'#13#10'interface'#13#10 +
    'type TRec = record Value: Integer; end;'#13#10'implementation'#13#10 +
    'procedure BeforeHelper;'#13#10'var lRecord: TRec; Count: Integer;'#13#10 +
    'begin'#13#10'  with lRecord do Count := 1;'#13#10'end;'#13#10 +
    'type'#13#10'  &THelp = record helper for TRec'#13#10 +
    '    function Count: Integer;'#13#10'  end;'#13#10 +
    'procedure AfterHelper;'#13#10'var lRecord: TRec; Count: Integer;'#13#10 +
    'begin'#13#10'  with lRecord do Count := 1;'#13#10'end;'#13#10 +
    'function &THelp.Count: Integer;'#13#10'begin Result := 1; end;'#13#10'end.';
  if aMode = 'overloads' then
    lSource := 'unit HelperCache;'#13#10 +
      'interface'#13#10 +
      'type'#13#10 +
      '  TRec = record Value: Integer; end;'#13#10 +
      '  TAlias = TRec;'#13#10 +
      'procedure Run; overload;'#13#10 +
      'procedure Run(X: Integer); overload;'#13#10 +
      'implementation'#13#10 +
      'var'#13#10 +
      '  GRec: TRec;'#13#10 +
      '  Count: Integer;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      '  with GRec do Count := 1;'#13#10 +
      'end;'#13#10 +
      'type'#13#10 +
      '  &THelp = record helper for TAlias'#13#10 +
      '    class var FCount: Integer;'#13#10 +
      '    class property Count: Integer read FCount write FCount;'#13#10 +
      '  end;'#13#10 +
      'procedure Run(X: Integer);'#13#10 +
      'begin'#13#10 +
      '  with GRec do Count := 2;'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  TFile.WriteAllText(lOptions.SourceFileName, lSource, TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  if aMode = 'lost' then
  begin
    lObject := TJSONObject.ParseJSONValue(ModelToJson(lModel)) as TJSONObject;
    try
      lValue := lObject.RemovePair('UnindexedHelpers');
      lValue.Free;
      lModel := JsonToModel(lObject.ToJSON);
    finally
      lObject.Free;
    end;
  end;
  lFacts := TDelphiSemanticWithBinder.BindProject('helper-cache', nil, [lModel]);
  Assert.AreEqual(2, Integer(Length(lFacts.Bindings)));
  lCount := 0;
  for lBinding in lFacts.Bindings do
    for lReference in lBinding.References do
      if SameText(lReference.Name, 'Count') then
      begin
        Inc(lCount);
        lExpected := 'unsupported';
        if (aMode <> 'lost') and
          (lBinding.Line < lModel.UnindexedHelpers[0].Line) then
          lExpected := 'lexical';
        Assert.AreEqual(lExpected, lReference.Classification, lBinding.RoutineName);
        if lExpected = 'unsupported' then
          Assert.AreEqual('RECORD_HELPER_MEMBERS_UNVERIFIED', lReference.ReasonCode);
      end;
  Assert.AreEqual(2, lCount);
end;

procedure TWithBinderTests.MalformedImportedHelperFactsFailClosed(const aMode: string);
var
  g: TGarbos;
  lOptions: TDelphiSemanticModelOptions;
  lRecordModel, lHelperModel, lSiteModel: TDelphiSemanticUnitModel;
  lObject, lEntry: TJSONObject;
  lPair: TJSONPair;
  lArray: TJSONArray;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lField, lKind: string;
  lValue: TJSONValue;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := WithBinderTempPath('MalformedRecord-' + StringReplace(aMode, ':', '-', [rfReplaceAll]) + '.pas');
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit MalformedRecord;'#13#10'interface'#13#10 +
    'type TRec = record Value: Integer; end;'#13#10'implementation'#13#10'end.', TEncoding.ASCII);
  lRecordModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  lOptions.SourceFileName := WithBinderTempPath('MalformedHelper-' + StringReplace(aMode, ':', '-', [rfReplaceAll]) + '.pas');
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit MalformedHelper;'#13#10'interface'#13#10'uses MalformedRecord;'#13#10 +
    'type'#13#10'  &THelp = record helper for TRec'#13#10 +
    '    function Count: Integer;'#13#10'  end;'#13#10'implementation'#13#10 +
    'function &THelp.Count: Integer;'#13#10'begin Result := 1; end;'#13#10'end.', TEncoding.ASCII);
  lHelperModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.AreEqual(1, Integer(Length(lHelperModel.UnindexedHelpers)));
  lObject := TJSONObject.ParseJSONValue(ModelToJson(lHelperModel)) as TJSONObject;
  GC(lObject, g);
  lPair := lObject.RemovePair('UnindexedHelpers');
  lPair.Free;
  lArray := TJSONArray.Create;
  lObject.AddPair('UnindexedHelpers', lArray);
  lEntry := nil;
  if aMode = 'null' then
    lArray.AddElement(TJSONNull.Create)
  else
  begin
    lEntry := TJSONObject.Create;
    lArray.AddElement(lEntry);
    lEntry.AddPair('Name', 'THelp');
    if aMode = 'null-target' then
      lEntry.AddPair('TargetName', TJSONNull.Create);
    lEntry.AddPair('HelperKind', 'record');
    lEntry.AddPair('SectionKind', 'interface');
    lEntry.AddPair('ScopeKind', 'unit');
    lEntry.AddPair('OwnerScopeId', 'malformedhelper');
  end;
  if Pos(':', aMode) > 0 then
  begin
    lField := Copy(aMode, 1, Pos(':', aMode) - 1);
    lKind := Copy(aMode, Pos(':', aMode) + 1, MaxInt);
    lEntry.AddPair('TargetName', 'TRec');
    lEntry.AddPair('FileName', '');
    lPair := lEntry.RemovePair(lField);
    lPair.Free;
    if lKind = 'number' then
      lValue := TJSONNumber.Create(123)
    else if lKind = 'bool' then
      lValue := TJSONBool.Create(True)
    else if lKind = 'null' then
      lValue := TJSONNull.Create
    else
      lValue := TJSONString.Create('bogus');
    lEntry.AddPair(lField, lValue);
  end;
  lHelperModel := JsonToModel(lObject.ToJSON);
  lOptions.SourceFileName := WithBinderTempPath('MalformedSite-' + StringReplace(aMode, ':', '-', [rfReplaceAll]) + '.pas');
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit MalformedSite;'#13#10'interface'#13#10'uses MalformedRecord, MalformedHelper;'#13#10 +
    'implementation'#13#10'procedure Run;'#13#10'var lRecord: TRec; Count: Integer;'#13#10 +
    'begin'#13#10'  with lRecord do Count := 1;'#13#10'end;'#13#10'end.', TEncoding.ASCII);
  lSiteModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  lFacts := TDelphiSemanticWithBinder.BindProject('malformed-helper', nil,
    [lRecordModel, lHelperModel, lSiteModel]);
  Assert.AreEqual(1, Integer(Length(lFacts.Bindings)));
  Assert.IsTrue(HasReference(lFacts.Bindings[0], 'Count', 'unsupported'),
    'Malformed imported helper facts cannot authorize lexical fallback.');
  Assert.AreEqual('RECORD_HELPER_MEMBERS_UNVERIFIED',
    ReasonOf(lFacts.Bindings[0], 'Count', 'unsupported'));
  Assert.AreEqual(0, Integer(Length(lHelperModel.UnindexedHelpers)),
    'Malformed entries must not count as valid helper facts.');
end;


procedure TWithBinderTests.MalformedHelperCoordinatesFailClosed(const aMode: string);
var
  g: TGarbos;
  lOptions: TDelphiSemanticModelOptions;
  lModel: TDelphiSemanticUnitModel;
  lObject, lEntry: TJSONObject;
  lArray: TJSONArray;
  lPair: TJSONPair;
  lValue: TJSONValue;
  lField, lKind: string;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := WithBinderTempPath('coordinates-' +
    StringReplace(aMode, ':', '-', [rfReplaceAll]) + '.pas');
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit CoordinateHelper;'#13#10'interface'#13#10 +
    'type TRec = record Value: Integer; end;'#13#10'implementation'#13#10 +
    'type'#13#10'  &THelp = record helper for TRec'#13#10 +
    '    procedure Count;'#13#10'  end;'#13#10 +
    'procedure Count;'#13#10'begin end;'#13#10 +
    'procedure Run;'#13#10'var lRecord: TRec;'#13#10 +
    'begin'#13#10'  with lRecord do Count();'#13#10'end;'#13#10 +
    'procedure &THelp.Count;'#13#10'begin end;'#13#10'end.', TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.AreEqual(1, Integer(Length(lModel.UnindexedHelpers)));
  lFacts := TDelphiSemanticWithBinder.BindProject('coordinate-cold', nil, [lModel]);
  Assert.AreEqual(1, Integer(Length(lFacts.Bindings)));
  Assert.IsTrue(HasReference(lFacts.Bindings[0], 'Count', 'unsupported'));
  Assert.AreEqual('RECORD_HELPER_MEMBERS_UNVERIFIED',
    ReasonOf(lFacts.Bindings[0], 'Count', 'unsupported'));
  lObject := TJSONObject.ParseJSONValue(ModelToJson(lModel)) as TJSONObject;
  GC(lObject, g);
  lArray := lObject.GetValue('UnindexedHelpers') as TJSONArray;
  lEntry := lArray.Items[0] as TJSONObject;
  lField := Copy(aMode, 1, Pos(':', aMode) - 1);
  lKind := Copy(aMode, Pos(':', aMode) + 1, MaxInt);
  if lField = 'Column' then
  begin
    // A string column can move the helper past the WITH on the same physical line.
    lPair := lEntry.RemovePair('Line');
    lPair.Free;
    lEntry.AddPair('Line', TJSONNumber.Create(lFacts.Bindings[0].Line));
  end;
  lPair := lEntry.RemovePair(lField);
  lPair.Free;
  lValue := nil;
  if lKind = 'string' then
    lValue := TJSONString.Create('999')
  else if lKind = 'float' then
    lValue := TJSONNumber.Create('999.5')
  else if lKind = 'null' then
    lValue := TJSONNull.Create
  else if lKind = 'bool' then
    lValue := TJSONBool.Create(True)
  else if lKind = 'array' then
    lValue := TJSONArray.Create
  else if lKind = 'object' then
    lValue := TJSONObject.Create
  else if lKind = 'negative' then
    lValue := TJSONNumber.Create(-1)
  else if lKind = 'overflow' then
    lValue := TJSONNumber.Create('2147483648');
  if Assigned(lValue) then
    lEntry.AddPair(lField, lValue);
  lModel := JsonToModel(lObject.ToJSON);
  lFacts := TDelphiSemanticWithBinder.BindProject('coordinate-reloaded', nil, [lModel]);
  Assert.AreEqual(1, Integer(Length(lFacts.Bindings)));
  Assert.IsTrue(HasReference(lFacts.Bindings[0], 'Count', 'unsupported'),
    'Malformed coordinates must refuse the helper call: ' + aMode);
  Assert.AreEqual('RECORD_HELPER_MEMBERS_UNVERIFIED',
    ReasonOf(lFacts.Bindings[0], 'Count', 'unsupported'));
  Assert.AreEqual(0, Integer(Length(lModel.UnindexedHelpers)),
    'Malformed coordinates must not count as valid facts: ' + aMode);
end;

procedure TWithBinderTests.HelperCoordinatesWriterRoundTrip(const aMode: string);
var
  lOptions: TDelphiSemanticModelOptions;
  lModel, lDecoded: TDelphiSemanticUnitModel;
  lCold, lReloaded: TDelphiSemanticProjectWithBindingFacts;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := WithBinderTempPath('writer-coordinate-' + aMode + '.pas');
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit WriterCoordinate;'#13#10'interface'#13#10 +
    'type TRec = record Value: Integer; end;'#13#10'implementation'#13#10 +
    'type'#13#10'  &THelp = record helper for TRec'#13#10 +
    '    procedure Count;'#13#10'  end;'#13#10 +
    'procedure Run;'#13#10'var lRecord: TRec;'#13#10 +
    'begin'#13#10'  with lRecord do Count();'#13#10'end;'#13#10 +
    'procedure &THelp.Count;'#13#10'begin end;'#13#10'end.', TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.AreEqual(1, Integer(Length(lModel.UnindexedHelpers)));
  if aMode = 'zero' then
  begin
    lModel.UnindexedHelpers[0].Line := 0;
    lModel.UnindexedHelpers[0].Column := 0;
  end;
  lDecoded := JsonToModel(ModelToJson(lModel));
  Assert.AreEqual(ModelToJson(lModel), ModelToJson(lDecoded));
  lCold := TDelphiSemanticWithBinder.BindProject('writer-coordinate-cold', nil, [lModel]);
  lReloaded := TDelphiSemanticWithBinder.BindProject('writer-coordinate-reload', nil, [lDecoded]);
  Assert.AreEqual(1, Integer(Length(lCold.Bindings)));
  Assert.AreEqual(1, Integer(Length(lReloaded.Bindings)));
  Assert.IsTrue(HasReference(lCold.Bindings[0], 'Count', 'unsupported'));
  Assert.IsTrue(HasReference(lReloaded.Bindings[0], 'Count', 'unsupported'));
  Assert.AreEqual('RECORD_HELPER_MEMBERS_UNVERIFIED',
    ReasonOf(lReloaded.Bindings[0], 'Count', 'unsupported'));
end;

procedure TWithBinderTests.UnindexedHelperWriterValuesRoundTrip(const aMode: string);
var
  lOptions: TDelphiSemanticModelOptions;
  lModel, lDecoded: TDelphiSemanticUnitModel;
  lCold, lReloaded: TDelphiSemanticProjectWithBindingFacts;
  lReference: TDelphiSemanticBoundReference;
  lCount: Integer;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := WithBinderTempPath('writer-values-' + aMode + '.pas');
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit WriterValues;'#13#10'interface'#13#10 +
    'type TRec = record Value: Integer; end;'#13#10'implementation'#13#10 +
    'type'#13#10'  &THelp = record helper for TRec'#13#10 +
    '    function Count: Integer;'#13#10'  end;'#13#10 +
    'procedure Run;'#13#10'var lRecord: TRec; Count: Integer;'#13#10 +
    'begin'#13#10'  with lRecord do Count := 1;'#13#10'end;'#13#10 +
    'function &THelp.Count: Integer;'#13#10'begin Result := 1; end;'#13#10'end.',
    TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.AreEqual(1, Integer(Length(lModel.UnindexedHelpers)));
  // These are legitimate writer values when AST helper metadata is incomplete.
  if aMode = 'kind' then
    lModel.UnindexedHelpers[0].HelperKind := ''
  else
    lModel.UnindexedHelpers[0].TargetName := '';
  lDecoded := JsonToModel(ModelToJson(lModel));
  Assert.AreEqual(1, Integer(Length(lDecoded.UnindexedHelpers)),
    'Writer-produced empty metadata must survive JSON reload.');
  Assert.AreEqual(ModelToJson(lModel), ModelToJson(lDecoded));
  lCold := TDelphiSemanticWithBinder.BindProject('writer-cold', nil, [lModel]);
  lReloaded := TDelphiSemanticWithBinder.BindProject('writer-reloaded', nil, [lDecoded]);
  Assert.AreEqual(1, Integer(Length(lCold.Bindings)));
  Assert.AreEqual(1, Integer(Length(lReloaded.Bindings)));
  lCount := 0;
  for lReference in lCold.Bindings[0].References do
    if SameText(lReference.Name, 'Count') then
    begin
      Inc(lCount);
      Assert.IsTrue(HasReference(lReloaded.Bindings[0], 'Count', lReference.Classification),
        'Cold and JSON-reloaded models must make the same binding decision.');
      Assert.AreEqual(lReference.ReasonCode,
        ReasonOf(lReloaded.Bindings[0], 'Count', lReference.Classification));
    end;
  Assert.AreEqual(1, lCount);
end;

procedure TWithBinderTests.UnindexedHelperCacheSeparatesSiteModels(const aOrder: string);
var
  lOptions: TDelphiSemanticModelOptions;
  lRecordModel, lHelperModel, lNoHelper, lHasHelper: TDelphiSemanticUnitModel;
  lFacts, lAlone: TDelphiSemanticProjectWithBindingFacts;
  lBinding: TDelphiSemanticWithBinding;
  lSource, lExpected: string;
  i: Integer;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := WithBinderTempPath('duplicate-record-' + aOrder + '.pas');
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit TypesA;'#13#10'interface'#13#10 +
    'type TRec = record Value: Integer; end;'#13#10'implementation'#13#10'end.',
    TEncoding.ASCII);
  lRecordModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  lOptions.SourceFileName := WithBinderTempPath('duplicate-helper-' + aOrder + '.pas');
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit Helpers;'#13#10'interface'#13#10'uses TypesA;'#13#10 +
    'type'#13#10'  &THelp = record helper for TypesA.TRec'#13#10 +
    '    function Count: Integer;'#13#10'  end;'#13#10'implementation'#13#10 +
    'function &THelp.Count: Integer;'#13#10'begin Result := 1; end;'#13#10'end.',
    TEncoding.ASCII);
  lHelperModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.AreEqual(1, Integer(Length(lHelperModel.UnindexedHelpers)));
  lSource := 'unit Consumer;'#13#10'interface'#13#10'uses TypesA%s;'#13#10 +
    'implementation'#13#10'procedure Run;'#13#10 +
    'var lRecord: TypesA.TRec; Count: Integer;'#13#10'begin'#13#10 +
    '  with lRecord do Count := 1;'#13#10 +
    '  with lRecord do Count := 2;'#13#10'end;'#13#10'end.';
  lOptions.SourceFileName := WithBinderTempPath('duplicate-no-helper-' + aOrder + '.pas');
  TFile.WriteAllText(lOptions.SourceFileName, Format(lSource, ['']), TEncoding.ASCII);
  lNoHelper := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  lOptions.SourceFileName := WithBinderTempPath('duplicate-has-helper-' + aOrder + '.pas');
  TFile.WriteAllText(lOptions.SourceFileName, Format(lSource, [', Helpers']), TEncoding.ASCII);
  lHasHelper := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  // Alone controls also pin intra-model cache reuse for both visibility states.
  for i := 0 to 1 do
  begin
    if i = 0 then
    begin
      lAlone := TDelphiSemanticWithBinder.BindProject('alone-no-helper', nil,
        [lRecordModel, lHelperModel, lNoHelper]);
      lExpected := 'lexical';
    end else begin
      lAlone := TDelphiSemanticWithBinder.BindProject('alone-has-helper', nil,
        [lRecordModel, lHelperModel, lHasHelper]);
      lExpected := 'unsupported';
    end;
    Assert.AreEqual(2, Integer(Length(lAlone.Bindings)));
    Assert.AreEqual(Int64(1), lAlone.Metrics.ReferenceCacheHitCount);
    Assert.AreEqual(Int64(1), lAlone.Metrics.ReferenceCacheMissCount);
    for lBinding in lAlone.Bindings do
      Assert.IsTrue(HasReference(lBinding, 'Count', lExpected), 'Isolated ' + lExpected);
  end;
  if aOrder = 'forward' then
    lFacts := TDelphiSemanticWithBinder.BindProject('combined', nil,
      [lRecordModel, lHelperModel, lNoHelper, lHasHelper])
  else
    lFacts := TDelphiSemanticWithBinder.BindProject('combined', nil,
      [lRecordModel, lHelperModel, lHasHelper, lNoHelper]);
  Assert.AreEqual(4, Integer(Length(lFacts.Bindings)));
  for lBinding in lFacts.Bindings do
  begin
    if SameText(lBinding.FileName, lHasHelper.FileName) then
      lExpected := 'unsupported'
    else
      lExpected := 'lexical';
    Assert.IsTrue(HasReference(lBinding, 'Count', lExpected),
      'Combined binding must match isolated site: ' + lExpected);
    if lExpected = 'unsupported' then
      Assert.AreEqual('RECORD_HELPER_MEMBERS_UNVERIFIED',
        ReasonOf(lBinding, 'Count', lExpected));
  end;
  Assert.AreEqual(Int64(2), lFacts.Metrics.ReferenceCacheHitCount);
  Assert.AreEqual(Int64(2), lFacts.Metrics.ReferenceCacheMissCount);
end;

procedure TWithBinderTests.UnindexedHelperIncludeOrigins(const aMode: string);
var
  lOptions: TDelphiSemanticModelOptions;
  lModel: TDelphiSemanticUnitModel;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lSource, lHelper, lInclude, lIncludePath: string;
  lExpectedLine: Integer;
  i: Integer;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := WithBinderTempPath('HelperOrigin-' + aMode + '.pas');
  lIncludePath := ChangeFileExt(lOptions.SourceFileName, '.inc');
  lHelper := 'type'#13#10'  &THelp = record helper for TRec'#13#10 +
    '    function Count: Integer;'#13#10'  end;'#13#10;
  lInclude := '// padding'#13#10'// padding'#13#10'// padding'#13#10;
  if aMode = 'included' then
    lInclude := lHelper;
  TFile.WriteAllText(lIncludePath, lInclude, TEncoding.ASCII);
  lSource := 'unit HelperOrigin;'#13#10'interface'#13#10 +
    'type TRec = record Value: Integer; end;'#13#10'implementation'#13#10 +
    '{$I ' + TPath.GetFileName(lIncludePath) + '}'#13#10;
  if aMode = 'before' then
    lSource := lSource + lHelper;
  lSource := lSource + 'procedure Count;'#13#10'begin end;'#13#10 +
    'procedure Run;'#13#10'var lRecord: TRec;'#13#10'begin'#13#10 +
    '  with lRecord do Count();'#13#10'end;'#13#10;
  if aMode = 'after' then
    lSource := lSource + lHelper;
  lSource := lSource + 'function &THelp.Count: Integer;'#13#10 +
    'begin Result := 1; end;'#13#10'end.';
  TFile.WriteAllText(lOptions.SourceFileName, lSource, TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(1, Integer(Length(lModel.UnindexedHelpers)));
  if aMode = 'included' then
  begin
    Assert.IsTrue(SameFileName(lIncludePath, lModel.UnindexedHelpers[0].FileName));
    Assert.AreEqual(0, lModel.UnindexedHelpers[0].Line);
    Assert.AreEqual(0, lModel.UnindexedHelpers[0].Column);
  end else begin
    lExpectedLine := 1;
    for i := 1 to Pos('&THelp =', lSource) - 1 do
      if lSource[i] = #10 then
        Inc(lExpectedLine);
    Assert.AreEqual('', lModel.UnindexedHelpers[0].FileName);
    Assert.AreEqual(lExpectedLine, lModel.UnindexedHelpers[0].Line,
      'Root-origin helper must retain its physical line after include expansion.');
    Assert.AreEqual(3, lModel.UnindexedHelpers[0].Column);
  end;
  lFacts := TDelphiSemanticWithBinder.BindProject('helper-origins', nil, [lModel]);
  Assert.AreEqual(1, Integer(Length(lFacts.Bindings)));
  lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
  Assert.AreEqual(1, Integer(Length(lPlan.FinalStatements)));
  if aMode = 'after' then
  begin
    Assert.IsTrue(HasReference(lFacts.Bindings[0], 'Count', 'external'));
    Assert.AreEqual('UNKNOWN_ROUTINE_CALL', ReasonOf(lFacts.Bindings[0], 'Count', 'external'));
    Assert.AreEqual('planned', lPlan.FinalStatements[0].Status);
    Assert.AreEqual(2, Integer(Length(lPlan.FinalStatements[0].Edits)));
  end else begin
    Assert.IsTrue(HasReference(lFacts.Bindings[0], 'Count', 'unsupported'));
    Assert.AreEqual('skipped', lPlan.FinalStatements[0].Status);
    Assert.AreEqual('symbol-not-found', lPlan.FinalStatements[0].Reason);
    Assert.AreEqual('RECORD_HELPER_MEMBERS_UNVERIFIED', lPlan.FinalStatements[0].SafetyReason);
    Assert.AreEqual(0, Integer(Length(lPlan.FinalStatements[0].Edits)));
  end;
end;

procedure TWithBinderTests.UnindexedHelperColdWarmSnapshot;
var
  lRoot: string;
  lOptions: TDelphiSemanticApiOptions;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lPlan, lSnapshotPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
  lEdit: TDelphiSemanticRemoveWithEdit;
  lPass, lAffected, lControls: Integer;
begin
  lRoot := WithBinderTempPath('helper-session-' + TPath.GetGUIDFileName);
  TDirectory.CreateDirectory(lRoot);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P; uses Unit1, ControlUnit; begin end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dproj'),
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="Unit1.pas"/>' +
    '<DCCReference Include="ControlUnit.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
    'unit Unit1;'#13#10'interface'#13#10'type TRec = record Value: Integer; end;'#13#10 +
    '  &THelp = record helper for TRec'#13#10'    function Count: Integer;'#13#10'  end;'#13#10 +
    'implementation'#13#10'function &THelp.Count: Integer;'#13#10'begin Result := 1; end;'#13#10 +
    'procedure Run;'#13#10'var lRecord: TRec; Count: Integer;'#13#10 +
    'begin'#13#10'  with lRecord do Count := 1;'#13#10'end;'#13#10'end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'ControlUnit.pas'),
    'unit ControlUnit;'#13#10'interface'#13#10'type TRec = record Count: Integer; end;'#13#10 +
    'var Rec: TRec;'#13#10'implementation'#13#10 +
    'procedure Run; begin with Rec do Count := Count + 1; end;'#13#10'end.', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.Combine(lRoot, 'P.dproj');
  lOptions.Cache.SqliteCacheFileName := TPath.Combine(lRoot, 'helper-session.sqlite');
  for lPass := 0 to 1 do
  begin
    lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lOptions);
    lAffected := 0;
    lControls := 0;
    for lStatement in lPlan.FinalStatements do
      if SameText(ExtractFileName(lStatement.FileName), 'Unit1.pas') then
      begin
        Inc(lAffected);
        Assert.AreEqual('skipped', lStatement.Status);
        Assert.AreEqual('receiver-member-not-found', lStatement.Reason);
        Assert.AreEqual('RECORD_HELPER_MEMBERS_UNVERIFIED', lStatement.SafetyReason);
        Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
        Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
        Assert.AreEqual('', lStatement.ReplacementText);
      end else if SameText(ExtractFileName(lStatement.FileName), 'ControlUnit.pas') then
      begin
        Inc(lControls);
        Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
      end;
    Assert.AreEqual(1, lAffected);
    Assert.AreEqual(1, lControls);
    for lEdit in lPlan.Edits do
      Assert.IsFalse(SameText(ExtractFileName(lEdit.FileName), 'Unit1.pas'));
    lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
    lSnapshotPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWithCompatibilitySnapshot(lFacts);
    Assert.AreEqual(Integer(Length(lPlan.FinalStatements)), Integer(Length(lSnapshotPlan.FinalStatements)));
    Assert.AreEqual(lPlan.FinalStatements[0].Status, lSnapshotPlan.FinalStatements[0].Status);
    Assert.AreEqual(lPlan.FinalStatements[0].Reason, lSnapshotPlan.FinalStatements[0].Reason);
    Assert.AreEqual(lPlan.FinalStatements[0].SafetyReason, lSnapshotPlan.FinalStatements[0].SafetyReason);
    Assert.AreEqual(lPlan.FinalStatements[0].ReplacementText, lSnapshotPlan.FinalStatements[0].ReplacementText);
  end;
end;

function TWithBinderTests.TypeValueMemberModels(const aShape: string): TArray<TDelphiSemanticUnitModel>;
var
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lSource, lShape: string;
begin
  lShape := StringReplace(aShape, '-lf', '', []);
  lSource := '';
  if lShape = 'rc-global-read' then
    lSource := 'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'type'#13#10 +
      '  TRec = record'#13#10 +
      '    const Count = 5;'#13#10 +
      '    var Other: Integer;'#13#10 +
      '  end;'#13#10 +
      'var Rec: TRec;'#13#10 +
      'var'#13#10 +
      '  Count: Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      '  with Rec do Other := Count;'#13#10 +
      'end;'#13#10 +
      'end.'#13#10
  else if lShape = 'rc-noglobal-read' then
    lSource := 'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'type'#13#10 +
      '  TRec = record'#13#10 +
      '    const Count = 5;'#13#10 +
      '    var Other: Integer;'#13#10 +
      '  end;'#13#10 +
      'var Rec: TRec;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      '  with Rec do Other := Count;'#13#10 +
      'end;'#13#10 +
      'end.'#13#10
  else if lShape = 'rc-header-sameline' then
    lSource := 'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'type TRec = record'#13#10 +
      '    const Count = 5;'#13#10 +
      '    var Other: Integer;'#13#10 +
      '  end;'#13#10 +
      'var Rec: TRec;'#13#10 +
      'var'#13#10 +
      '  Count: Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      '  with Rec do Other := Count;'#13#10 +
      'end;'#13#10 +
      'end.'#13#10
  else if lShape = 'rc-sameline-end' then
    lSource := 'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'type TRec = record var Other: Integer; const Count = 5; end;'#13#10 +
      'var Rec: TRec;'#13#10 +
      'var'#13#10 +
      '  Count: Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      '  with Rec do Other := Count;'#13#10 +
      'end;'#13#10 +
      'end.'#13#10
  else if lShape = 'rc-typed' then
    lSource := 'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'type'#13#10 +
      '  TRec = record'#13#10 +
      '    const Count: Integer = 5;'#13#10 +
      '    var Other: Integer;'#13#10 +
      '  end;'#13#10 +
      'var Rec: TRec;'#13#10 +
      'var'#13#10 +
      '  Count: Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      '  with Rec do Other := Count;'#13#10 +
      'end;'#13#10 +
      'end.'#13#10
  else if lShape = 'vt-global-read' then
    lSource := 'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'type'#13#10 +
      '  TRec = record'#13#10 +
      '    Other: Integer;'#13#10 +
      '    case Count: Integer of'#13#10 +
      '      0: (A: Integer);'#13#10 +
      '      1: (B: Byte);'#13#10 +
      '  end;'#13#10 +
      'var Rec: TRec;'#13#10 +
      'var'#13#10 +
      '  Count: Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      '  with Rec do A := Count;'#13#10 +
      'end;'#13#10 +
      'end.'#13#10
  else if lShape = 'vt-noglobal-read' then
    lSource := 'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'type'#13#10 +
      '  TRec = record'#13#10 +
      '    Other: Integer;'#13#10 +
      '    case Count: Integer of'#13#10 +
      '      0: (A: Integer);'#13#10 +
      '      1: (B: Byte);'#13#10 +
      '  end;'#13#10 +
      'var Rec: TRec;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      '  with Rec do A := Count;'#13#10 +
      'end;'#13#10 +
      'end.'#13#10
  else if lShape = 'vt-header-sameline' then
    lSource := 'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'type TRec = record'#13#10 +
      '    case Count: Integer of'#13#10 +
      '      0: (A: Integer);'#13#10 +
      '  end;'#13#10 +
      'var Rec: TRec;'#13#10 +
      'var'#13#10 +
      '  Count: Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      '  with Rec do A := Count;'#13#10 +
      'end;'#13#10 +
      'end.'#13#10
  else if lShape = 'vt-alias-recv' then
    lSource := 'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'type'#13#10 +
      '  TRec = record'#13#10 +
      '    Other: Integer;'#13#10 +
      '    case Count: Integer of'#13#10 +
      '      0: (A: Integer);'#13#10 +
      '      1: (B: Byte);'#13#10 +
      '  end;'#13#10 +
      '  TRec2 = TRec;'#13#10 +
      'var Rec: TRec2;'#13#10 +
      'var'#13#10 +
      '  Count: Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      '  with Rec do A := Count;'#13#10 +
      'end;'#13#10 +
      'end.'#13#10
  else if lShape = 'vt-nested-with' then
    lSource := 'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'type'#13#10 +
      '  TRec = record'#13#10 +
      '    Other: Integer;'#13#10 +
      '    case Count: Integer of'#13#10 +
      '      0: (A: Integer);'#13#10 +
      '      1: (B: Byte);'#13#10 +
      '  end;'#13#10 +
      '  TOuter = record'#13#10 +
      '    Count: Integer;'#13#10 +
      '  end;'#13#10 +
      'var Rec: TRec;'#13#10 +
      '  Outer: TOuter;'#13#10 +
      'var'#13#10 +
      '  Count: Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      '  with Outer do with Rec do A := Count;'#13#10 +
      'end;'#13#10 +
      'end.'#13#10
  else if lShape = 'cc-inherited' then
    lSource := 'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'type'#13#10 +
      '  TBase = class'#13#10 +
      '  public'#13#10 +
      '    const Count = 5;'#13#10 +
      '  end;'#13#10 +
      '  TDerived = class(TBase)'#13#10 +
      '  public'#13#10 +
      '    Other: Integer;'#13#10 +
      '  end;'#13#10 +
      'var Obj: TDerived;'#13#10 +
      'var'#13#10 +
      '  Count: Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      '  with Obj do Other := Count;'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  Assert.IsNotEmpty(lSource, 'Unknown DS-731 fixture');
  if EndsText('-lf', aShape) then
    lSource := StringReplace(lSource, #13#10, #10, [rfReplaceAll]);
  lPath := WithBinderTempPath('DS731-' + aShape + '.pas');
  TFile.WriteAllText(lPath, lSource, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  SetLength(Result, 1);
  Result[0] := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(Result[0].Success, aShape);
  Assert.AreEqual('ast', Result[0].ScopeModelStatus, aShape);
end;

procedure TWithBinderTests.TypeValueMembersBind(const aShape: string);
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lReference: TDelphiSemanticBoundReference;
  lFound: Boolean;
begin
  lFacts := TDelphiSemanticWithBinder.BindProject('ds731-' + aShape, nil, TypeValueMemberModels(aShape));
  Assert.IsTrue(Length(lFacts.Bindings) > 0, aShape);
  lFound := False;
  for lReference in lFacts.Bindings[High(lFacts.Bindings)].References do
    if SameText(lReference.Name, 'Count') then
    begin
      lFound := True;
      Assert.AreEqual('member', lReference.Classification, aShape);
      Assert.AreEqual('receiver', lReference.LookupSource, aShape);
      Assert.IsTrue(MatchText(lReference.Kind, ['const', 'typed-const', 'variant-tag']), aShape);
    end;
  Assert.IsTrue(lFound, 'Count reference must be observed: ' + aShape);
end;

procedure TWithBinderTests.TypeValueMembersPlan(const aShape: string);
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lPlan, lSnapshotPlan: TDelphiSemanticRemoveWithPlan;
  lExpected, lLineBreak: string;
  lTemps, lEdits: Integer;
begin
  lFacts := TDelphiSemanticWithBinder.BindProject('ds731-' + aShape, nil, TypeValueMemberModels(aShape));
  lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
  lSnapshotPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWithCompatibilitySnapshot(lFacts);
  Assert.AreEqual(1, Integer(Length(lPlan.FinalStatements)), aShape);
  Assert.AreEqual('planned', lPlan.FinalStatements[0].Status, aShape);
  lLineBreak := #13#10;
  // Temporary initialization lines follow the native renderer's CRLF contract,
  // including when the source fixture uses LF.
  lTemps := 1;
  lEdits := 2;
  lExpected := '  lWithRecPtr := @Rec;' + lLineBreak +
    ' lWithRecPtr^.Other := lWithRecPtr^.Count;';
  if StartsText('vt-', aShape) then
    lExpected := '  lWithRecPtr := @Rec;' + lLineBreak +
      ' lWithRecPtr^.A := lWithRecPtr^.Count;';
  if aShape = 'vt-alias-recv' then
  begin
    lExpected := ' Rec.A := Rec.Count;';
    lTemps := 0;
    lEdits := 1;
  end;
  if aShape = 'vt-nested-with' then
  begin
    lExpected := '  lWithOuterPtr := @Outer;' + lLineBreak +
      '               lWithRecPtr := @Rec;' + lLineBreak +
      ' lWithRecPtr^.A := lWithRecPtr^.Count;';
    lTemps := 2;
  end;
  if aShape = 'cc-inherited' then
    lExpected := '  lWithDerived := Obj;' + lLineBreak +
      ' lWithDerived.Other := lWithDerived.Count;';
  Assert.AreEqual(lExpected, lPlan.FinalStatements[0].ReplacementText, aShape);
  Assert.AreEqual(lTemps, Integer(Length(lPlan.FinalStatements[0].Temps)), aShape);
  Assert.AreEqual(lEdits, Integer(Length(lPlan.FinalStatements[0].Edits)), aShape);
  Assert.AreEqual(lExpected, lSnapshotPlan.FinalStatements[0].ReplacementText, aShape);
  Assert.AreEqual(lTemps, Integer(Length(lSnapshotPlan.FinalStatements[0].Temps)), aShape);
  Assert.AreEqual(lEdits, Integer(Length(lSnapshotPlan.FinalStatements[0].Edits)), aShape);
end;

procedure TWithBinderTests.ValueMemberQualificationRequiresVerifiedReceiver(
  const aShape, aMode: string);
begin
  ValueMembersColdWarmSnapshot(aShape, aMode);
end;

procedure TWithBinderTests.NestedValueQualificationRequiresVerifiedReceiver(
  const aShape, aMode: string);
begin
  ValueMembersColdWarmSnapshot(aShape, aMode);
end;

procedure TWithBinderTests.ValueCoverageUsesReceiverIdentity(const aShape, aMode: string);
begin
  ValueMembersColdWarmSnapshot(aShape, aMode);
end;

procedure TWithBinderTests.ModelFreeLookupCannotProveValueAbsence;
var
  lIndex: TDelphiSemanticRemoveWithLookupIndex;
begin
  lIndex := TDelphiSemanticRemoveWithLookupIndex.Build([], []);
  Assert.IsTrue(lIndex.IsAvailable, 'Inventory availability is not model coverage.');
  Assert.IsTrue(lIndex.UnverifiedValueMemberMayApply('TItem', 'Count'),
    'A model-free cache route must fail closed even with an empty value-name set.');
  lIndex.AttachValueMemberEvidence(Default(TDelphiSemanticValueMemberEvidence));
  Assert.IsTrue(lIndex.UnverifiedValueMemberMayApply('TItem', 'Count'),
    'An unavailable imported view must not witness an empty name set.');
end;

procedure CorruptStandaloneValueEvidence(const aFileName, aShape: string);
var
  g: TGarbos;
  lConnection: TFDConnection;
begin
  GC(lConnection, TFDConnection.Create(nil), g);
  lConnection.DriverName := 'SQLite';
  lConnection.Params.Values['Database'] := aFileName;
  lConnection.LoginPrompt := False;
  lConnection.Connected := True;
  if aShape = 'missing' then
    lConnection.ExecSQL('delete from snapshot_remove_with_value_evidence where row_kind = 0')
  else if aShape = 'format' then
    lConnection.ExecSQL('update snapshot_remove_with_value_evidence set evidence_version = 0 ' +
      'where row_kind = 0')
  else if aShape = 'checksum' then
    lConnection.ExecSQL('update snapshot_remove_with_value_evidence set count1 = count1 + 1 ' +
      'where row_kind = 0')
  else if aShape = 'models' then
    lConnection.ExecSQL('delete from snapshot_remove_with_value_evidence ' +
      'where row_kind = 1 and item_index = 0')
  else if aShape = 'fields' then
    lConnection.ExecSQL('delete from snapshot_remove_with_value_evidence ' +
      'where row_kind = 2 and item_index = 0')
  else if aShape = 'values' then
    lConnection.ExecSQL('delete from snapshot_remove_with_value_evidence ' +
      'where row_kind = 3 and item_index = 0');
end;

procedure AssertValueEvidenceEqual(const aExpected, aActual: TDelphiSemanticValueMemberEvidence;
  const aExpectedLookup, aActualLookup: TDelphiSemanticRemoveWithLookupIndex);
var
  i, j: Integer;
  lName: string;
begin
  Assert.AreEqual(aExpected.Available, aActual.Available);
  Assert.AreEqual(Length(aExpected.Units), Length(aActual.Units));
  for i := 0 to High(aExpected.Units) do
  begin
    Assert.AreEqual(aExpected.Units[i].UnitName, aActual.Units[i].UnitName);
    Assert.AreEqual(aExpected.Units[i].FileName, aActual.Units[i].FileName);
    Assert.AreEqual(aExpected.Units[i].SourceText, aActual.Units[i].SourceText);
    Assert.AreEqual(aExpected.Units[i].VerifiedActiveSourceText, aActual.Units[i].VerifiedActiveSourceText);
    Assert.AreEqual(aExpected.Units[i].ScopeModelStatus, aActual.Units[i].ScopeModelStatus);
    Assert.AreEqual(aExpected.Units[i].ScopeModelVersion, aActual.Units[i].ScopeModelVersion);
    Assert.AreEqual(aExpected.Units[i].RejectedDeclarationCount, aActual.Units[i].RejectedDeclarationCount);
  end;
  Assert.AreEqual(Length(aExpected.ValueNames), Length(aActual.ValueNames));
  for i := 0 to High(aExpected.ValueNames) do
    Assert.AreEqual(aExpected.ValueNames[i], aActual.ValueNames[i]);
  Assert.AreEqual(Length(aExpected.UnverifiedOwnerKeys), Length(aActual.UnverifiedOwnerKeys));
  for i := 0 to High(aExpected.UnverifiedOwnerKeys) do
    Assert.AreEqual(aExpected.UnverifiedOwnerKeys[i], aActual.UnverifiedOwnerKeys[i]);
  Assert.AreEqual(Length(aExpected.Owners), Length(aActual.Owners));
  for i := 0 to High(aExpected.Owners) do
  begin
    Assert.AreEqual(aExpected.Owners[i].DeclaredId, aActual.Owners[i].DeclaredId);
    Assert.AreEqual(aExpected.Owners[i].UnitName, aActual.Owners[i].UnitName);
    Assert.AreEqual(aExpected.Owners[i].FileName, aActual.Owners[i].FileName);
    Assert.AreEqual(aExpected.Owners[i].Name, aActual.Owners[i].Name);
    Assert.AreEqual(aExpected.Owners[i].Complete, aActual.Owners[i].Complete);
    Assert.AreEqual(aExpected.Owners[i].TerminalVerified, aActual.Owners[i].TerminalVerified);
    Assert.AreEqual(aExpected.Owners[i].UnindexedRoot, aActual.Owners[i].UnindexedRoot);
    Assert.AreEqual(aExpected.Owners[i].NextDeclaredId, aActual.Owners[i].NextDeclaredId);
    // A count of zero is an explicit empty-set witness, not absent evidence.
    Assert.AreEqual(Length(aExpected.Owners[i].ValueNames), Length(aActual.Owners[i].ValueNames));
    for j := 0 to High(aExpected.Owners[i].ValueNames) do
      Assert.AreEqual(aExpected.Owners[i].ValueNames[j], aActual.Owners[i].ValueNames[j]);
  end;
  Assert.AreEqual(Length(aExpected.Queries), Length(aActual.Queries));
  for i := 0 to High(aExpected.Queries) do
  begin
    Assert.AreEqual(aExpected.Queries[i].Name, aActual.Queries[i].Name);
    Assert.AreEqual(aExpected.Queries[i].DeclaredId, aActual.Queries[i].DeclaredId);
    for lName in aExpected.ValueNames + ['NoValueMember_DS731'] do
      Assert.AreEqual(aExpectedLookup.UnverifiedValueMemberMayApply(aExpected.Queries[i].Name, lName),
        aActualLookup.UnverifiedValueMemberMayApply(aExpected.Queries[i].Name, lName));
    for lName in aExpected.ValueNames + ['NoValueMember_DS731', 'A', 'X'] do
      Assert.AreEqual(aExpectedLookup.UnverifiedReceiverMemberMayApply(aExpected.Queries[i].Name,
        lName, Default(TDelphiSemanticTypeIdentity)),
        aActualLookup.UnverifiedReceiverMemberMayApply(aExpected.Queries[i].Name,
        lName, Default(TDelphiSemanticTypeIdentity)));

  end;
  Assert.AreEqual(aExpectedLookup.UnverifiedValueMemberMayApply('MissingOwner_DS731', 'Count'),
    aActualLookup.UnverifiedValueMemberMayApply('MissingOwner_DS731', 'Count'));
end;

procedure TWithBinderTests.StandaloneValueEvidenceRejectsPartial(const aShape: string);
begin
  ValueMembersColdWarmSnapshot('tag-only', 'corrupt-' + aShape);
end;

procedure TWithBinderTests.ValueMembersStandaloneSqlite(const aShape: string);
begin
  ValueMembersColdWarmSnapshot(aShape, 'standalone');
end;

procedure TWithBinderTests.AliasReceiverMembersBindAndPlan(const aShape, aMode: string);
var
  lRoot, lSource, lExpected: string;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticApiOptions;
  lPlan, lSnapshotPlan: TDelphiSemanticRemoveWithPlan;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lStored, lLoaded: TDelphiProjectSnapshot;
  lSession: TDelphiSemanticProjectSessionResult;
  lSessionBuild: TDelphiSemanticRemoveWithPlanBuildResult;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
  lHasMember, lRefused: Boolean;
  lSerializer: TJsonSerializer;
  g: TGarbos;
begin
  lRoot := WithBinderTempPath('DS741-' + aShape + '-' + aMode);
  TDirectory.CreateDirectory(lRoot);
  lSource := '';
  if aShape = 'strong-helper-global' then
    lSource := 'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'function M: Integer;'#13#10 +
      'type'#13#10 +
      ' TRec = record'#13#10 +
      '  A: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TRecHelper = record helper for TRec'#13#10 +
      '  function M: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TA = type TRec;'#13#10 +
      'var'#13#10 +
      ' Item: TA;'#13#10 +
      'implementation'#13#10 +
      'function TRecHelper.M: Integer; begin Result := 5; end;'#13#10 +
      'function M: Integer; begin Result := 100; end;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' with Item do A := M;'#13#10 +
      ' Writeln(Item.A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  if aShape = 'strong-own-helper-global' then
    lSource := 'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'function M: Integer;'#13#10 +
      'type'#13#10 +
      ' TRec = record'#13#10 +
      '  A: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TA = type TRec;'#13#10 +
      ' THelp = record helper for TA'#13#10 +
      '  function M: Integer;'#13#10 +
      ' end;'#13#10 +
      'var'#13#10 +
      ' Item: TA;'#13#10 +
      'implementation'#13#10 +
      'function THelp.M: Integer; begin Result := 5; end;'#13#10 +
      'function M: Integer; begin Result := 100; end;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' with Item do A := M;'#13#10 +
      ' Writeln(Item.A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  lExpected := ' Item.A := 7;';
  if aShape = 'weak-var-globalA' then
  begin
    lSource := 'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TItem = record'#13#10 +
      '  var A: Integer;'#13#10 +
      '  var Z: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TAlias = TItem;'#13#10 +
      'var'#13#10 +
      ' Item: TAlias;'#13#10 +
      ' A: Integer = 0;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' with Item do A := 7;'#13#10 +
      ' Writeln(Item.A, '' '', A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  end;
  if aShape = 'weak-var-noglobal' then
  begin
    lSource := 'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TItem = record'#13#10 +
      '  var A: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TAlias = TItem;'#13#10 +
      'var'#13#10 +
      ' Item: TAlias;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' with Item do A := 7;'#13#10 +
      ' Writeln(Item.A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  end;
  if aShape = 'alias-varA-noconst-globalA' then
  begin
    lSource := 'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TItem = record'#13#10 +
      '  var A: Integer;'#13#10 +
      '  var Z: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TAlias = TItem;'#13#10 +
      'var'#13#10 +
      ' Item: TAlias;'#13#10 +
      ' A: Integer = 0;'#13#10 +
      ' Count: Integer = 100;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' '#13#10 +
      ' with Item do A := 7;'#13#10 +
      ' Writeln(Item.A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  end;
  if aShape = 'strong-plain-globalA' then
  begin
    lSource := 'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TRec = record'#13#10 +
      '  A: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TA = type TRec;'#13#10 +
      'var'#13#10 +
      ' Item: TA;'#13#10 +
      ' A: Integer = 0;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' with Item do A := 7;'#13#10 +
      ' Writeln(Item.A, '' '', A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  end;
  if aShape = 'strong-plain-noglobal' then
  begin
    lSource := 'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TRec = record'#13#10 +
      '  A: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TA = type TRec;'#13#10 +
      'var'#13#10 +
      ' Item: TA;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' with Item do A := 7;'#13#10 +
      ' Writeln(Item.A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  end;
  if aShape = 'strong-var-globalA' then
  begin
    lSource := 'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TRec = record'#13#10 +
      '  var A: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TA = type TRec;'#13#10 +
      'var'#13#10 +
      ' Item: TA;'#13#10 +
      ' A: Integer = 0;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' with Item do A := 7;'#13#10 +
      ' Writeln(Item.A, '' '', A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  end;
  if aShape = 'strong-plain-readglobal' then
  begin
    lSource := 'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TRec = record'#13#10 +
      '  A: Integer;'#13#10 +
      '  B: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TA = type TRec;'#13#10 +
      'var'#13#10 +
      ' Item: TA;'#13#10 +
      ' A: Integer = 100;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' Item.A := 7;'#13#10 +
      ' with Item do B := A;'#13#10 +
      ' Writeln(Item.B);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    lExpected := ' Item.B := Item.A;';
  end;
  if aShape = 'strong-class-globalA' then
  begin
    lSource := 'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TBase = class'#13#10 +
      '  A: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TC = type TBase;'#13#10 +
      'var'#13#10 +
      ' Obj: TC;'#13#10 +
      ' A: Integer = 0;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' Obj := TC(TBase.Create);'#13#10 +
      ' with Obj do A := 7;'#13#10 +
      ' Writeln(Obj.A, '' '', A);'#13#10 +
      ' Obj.Free;'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    lExpected := ' Obj.A := 7;';
  end;
  if aShape = 'weak-varA-classvar-globalA' then
  begin
    lSource := 'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TItem = record'#13#10 +
      '  var A: Integer;'#13#10 +
      '  class var Count: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TAlias = TItem;'#13#10 +
      'var'#13#10 +
      ' Item: TAlias;'#13#10 +
      ' A: Integer = 0;'#13#10 +
      ' Count: Integer = 100;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' TItem.Count := 7;'#13#10 +
      ' with Item do A := Count;'#13#10 +
      ' Writeln(Item.A, '' '', A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    lExpected := ' Item.A := Item.Count;';
  end;
  if aShape = 'alias-varA-classvar-globalA' then
  begin
    lSource := 'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TItem = record'#13#10 +
      '  var A: Integer;'#13#10 +
      '  class var Count: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TAlias = TItem;'#13#10 +
      'var'#13#10 +
      ' Item: TAlias;'#13#10 +
      ' A: Integer = 0;'#13#10 +
      ' Count: Integer = 100;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' TItem.Count := 7;'#13#10 +
      ' with Item do A := Count;'#13#10 +
      ' Writeln(Item.A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    lExpected := ' Item.A := Item.Count;';
  end;
  if aShape = 'weak-chain-var-globalA' then
  begin
    lSource := 'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TItem = record'#13#10 +
      '  var A: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TAlias = TItem;'#13#10 +
      ' TAlias2 = TAlias;'#13#10 +
      'var'#13#10 +
      ' Item: TAlias2;'#13#10 +
      ' A: Integer = 0;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' with Item do A := 7;'#13#10 +
      ' Writeln(Item.A, '' '', A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  end;
  if aShape = 'weak-cross-unit-var-globalA' then
  begin
    lSource := 'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses Unit2;'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TAlias = Unit2.TItem;'#13#10 +
      'var'#13#10 +
      ' Item: TAlias;'#13#10 +
      ' A: Integer = 0;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' with Item do A := 7;'#13#10 +
      ' Writeln(Item.A, '' '', A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit2.pas'),
      'unit Unit2;'#13#10 +
      'interface'#13#10 +
      'type'#13#10 +
      ' TItem = record'#13#10 +
      '  var A: Integer;'#13#10 +
      ' end;'#13#10 +
      'implementation'#13#10 +
      'end.'#13#10, TEncoding.ASCII);
  end;
  if (aShape = 'local-weak-var-globalA') then
  begin
    lSource := 'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TItem = record'#13#10 +
      '  var A: Integer;'#13#10 +
      ' end;'#13#10 +
      'var'#13#10 +
      ' A: Integer = 0;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TL = TItem;'#13#10 +
      'var'#13#10 +
      ' Item: TL;'#13#10 +
      'begin'#13#10 +
      ' with Item do A := 7;'#13#10 +
      ' Writeln(Item.A, '' '', A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  end;
  if aShape = 'on-sib-a' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses System.SysUtils;'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TItem = record'#13#10 +
      '  var A: Integer;'#13#10 +
      '  const Count = 7;'#13#10 +
      ' end;'#13#10 +
      ' TAlias = TItem;'#13#10 +
      ' TItemV = record'#13#10 +
      '  A: Integer;'#13#10 +
      '  const Count = 7;'#13#10 +
      ' end;'#13#10 +
      ' TOther = record'#13#10 +
      '  B: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TExtra = record'#13#10 +
      '  C: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TO2 = record'#13#10 +
      '  B: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TO2A = TO2;'#13#10 +
      'var'#13#10 +
      ' Item, Item2: TAlias;'#13#10 +
      ' ItemV: TItemV;'#13#10 +
      ' Other: TOther;'#13#10 +
      ' Extra: TExtra;'#13#10 +
      ' Other2: TO2A;'#13#10 +
      'var A: Integer = 0;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      'with Item do begin try A := 6; except on Exception do with Extra do C := 1; end; with Other do B := A; end;'#13#10 +
      'Writeln(Item.A, '' '', Other.B, '' '', Extra.C, '' '', A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    lExpected :=       ' begin try Item.A := 6; except on Exception do begin'#13#10 +
      '                                                      lWithExtraPtr := @Extra;'#13#10 +
      ' lWithExtraPtr^.C := 1;'#13#10 +
      '                                                      end; end;                                                                                  lWithOtherPtr := @Other;'#13#10 +
      ' lWithOtherPtr^.B := Item.A; end;';
  end;
  if aShape = 'd-nested-twoline-noconst' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TItem = record'#13#10 +
      '  var A: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TAlias = TItem;'#13#10 +
      ' TOther = record'#13#10 +
      '  B: Integer;'#13#10 +
      ' end;'#13#10 +
      'var'#13#10 +
      ' Item: TAlias;'#13#10 +
      ' Other: TOther;'#13#10 +
      'var A: Integer = 0;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' Other.B := 5;'#13#10 +
      ' with Item do begin Writeln(7); with Other do A := B; end;'#13#10 +
      ' Writeln(Item.A);'#13#10 +
      ' '#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    lExpected :=       ' begin Writeln(7);                                 lWithOtherPtr := @Other;'#13#10 +
      ' Item.A := lWithOtherPtr^.B; end;';
  end;
  if aShape = 'unit-local-weak-var-globalA' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TItem = record'#13#10 +
      '  var A: Integer;'#13#10 +
      '  var Z: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TAlias = TItem;'#13#10 +
      'var'#13#10 +
      ' Item: TAlias;'#13#10 +
      ' A: Integer = 0;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' with Item do A := 7;'#13#10 +
      ' Writeln(Item.A, '' '', A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  end;
  if aShape = 'fix-helper-via-weak' then
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'function M: Integer;'#13#10 +
      'type'#13#10 +
      ' TRec = record'#13#10 +
      '  A: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TS = type TRec;'#13#10 +
      ' TS2 = TS;'#13#10 +
      ' THelp = record helper for TS2'#13#10 +
      '  function M: Integer;'#13#10 +
      ' end;'#13#10 +
      'var'#13#10 +
      ' Item: TS;'#13#10 +
      'implementation'#13#10 +
      'function THelp.M: Integer; begin Result := 5; end;'#13#10 +
      'function M: Integer; begin Result := 100; end;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' with Item do A := M;'#13#10 +
      ' Writeln(Item.A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  if aShape = 'fix-generic-record' then
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TGen<T> = record'#13#10 +
      '  var A: T;'#13#10 +
      ' end;'#13#10 +
      ' TIntRec = TGen<Integer>;'#13#10 +
      'var'#13#10 +
      ' Item: TIntRec;'#13#10 +
      ' A: Integer = 0;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' with Item do A := 7;'#13#10 +
      ' Writeln(Item.A, '' '', A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  if aShape = 'fix-generic-plain' then
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TGen<T> = record'#13#10 +
      '  A: T;'#13#10 +
      ' end;'#13#10 +
      ' TIntRec = TGen<Integer>;'#13#10 +
      'var'#13#10 +
      ' Item: TIntRec;'#13#10 +
      ' A: Integer = 0;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' with Item do A := 7;'#13#10 +
      ' Writeln(Item.A, '' '', A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  if aShape = 'fix-generic-class' then
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TGenC<T> = class'#13#10 +
      '  A: T;'#13#10 +
      ' end;'#13#10 +
      ' TIntC = TGenC<Integer>;'#13#10 +
      'var'#13#10 +
      ' Obj: TIntC;'#13#10 +
      ' A: Integer = 0;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' Obj := TIntC.Create;'#13#10 +
      ' with Obj do A := 7;'#13#10 +
      ' Writeln(Obj.A, '' '', A);'#13#10 +
      ' Obj.Free;'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  if aShape = 'fix-escaped' then
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      ''#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      'TItem = record'#13#10 +
      ' var A: Integer;'#13#10 +
      'end;'#13#10 +
      'TA = &TItem;'#13#10 +
      'var Item: TA;'#13#10 +
      ' A: Integer;'#13#10 +
      'implementation'#13#10 +
      ''#13#10 +
      'procedure Run;'#13#10 +
      ''#13#10 +
      'begin'#13#10 +
      ' with Item do A := 7;'#13#10 +
      ' Writeln(Item.A, '' '', A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  if aShape = 'fix-sol-generic' then
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      ''#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      'TItem<T> = record'#13#10 +
      ' var A: Integer;'#13#10 +
      'end;'#13#10 +
      'TA = TItem<Integer>;'#13#10 +
      'var Item: TA;'#13#10 +
      ' A: Integer;'#13#10 +
      'implementation'#13#10 +
      ''#13#10 +
      'procedure Run;'#13#10 +
      ''#13#10 +
      'begin'#13#10 +
      ' with Item do A := 7;'#13#10 +
      ' Writeln(Item.A, '' '', A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  if aShape = 'fix-local-strong' then
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      ''#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      'TItem = record'#13#10 +
      ' var A: Integer;'#13#10 +
      'end;'#13#10 +
      ''#13#10 +
      'var A: Integer;'#13#10 +
      'implementation'#13#10 +
      ''#13#10 +
      'procedure Run;'#13#10 +
      'type TA = type TItem;'#13#10 +
      'var Item: TA;'#13#10 +
      'begin'#13#10 +
      ' with Item do A := 7;'#13#10 +
      ' Writeln(Item.A, '' '', A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  if aShape = 'fix-helper-via-plain' then
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'function M: Integer;'#13#10 +
      'type'#13#10 +
      ' TRec = record'#13#10 +
      '  A: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TS = TRec;'#13#10 +
      ' TS2 = TS;'#13#10 +
      ' THelp = record helper for TS2'#13#10 +
      '  function M: Integer;'#13#10 +
      ' end;'#13#10 +
      'var'#13#10 +
      ' Item: TS;'#13#10 +
      'implementation'#13#10 +
      'function THelp.M: Integer; begin Result := 5; end;'#13#10 +
      'function M: Integer; begin Result := 100; end;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' with Item do A := M;'#13#10 +
      ' Writeln(Item.A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  lRefused := StartsText('fix-', aShape) and
    (not MatchText(aShape, ['fix-escaped', 'fix-helper-via-plain']));
  if aShape = 'fix-helper-via-plain' then
    lExpected := ' Item.A := Item.M;';
  Assert.AreNotEqual('', lSource, aShape);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'), lSource, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P; uses Unit1; begin Run; end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dproj'),
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="Unit1.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  if aShape = 'weak-cross-unit-var-globalA' then
  begin
    TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
      'program P; uses Unit2, Unit1; begin Run; end.', TEncoding.ASCII);
    TFile.WriteAllText(TPath.Combine(lRoot, 'P.dproj'),
      '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
      '<PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
      '<ItemGroup><DCCReference Include="Unit1.pas"/>' +
      '<DCCReference Include="Unit2.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  end;
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.Combine(lRoot, 'P.dproj');
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win64';
  lOptions.DelphiVersion := '23.0';
  lOptions.Cache.SqliteCacheFileName := TPath.Combine(lRoot, 'cache.sqlite');
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  lHasMember := False;
  for var lBinding in lFacts.Bindings do
    if HasReference(lBinding, 'A', 'member') then
    begin
      lHasMember := True;
      Assert.AreEqual('receiver', LookupSourceOf(lBinding, 'A', 'member'));
      Assert.IsNotEmpty(ReceiverOf(lBinding, 'A', 'member'));
    end;
  if lRefused or MatchText(aShape, ['strong-helper-global', 'strong-own-helper-global']) then
  begin
    Assert.IsTrue(HasReference(lFacts.Bindings[0], 'A', 'unsupported'));
    if aShape = 'fix-local-strong' then
      Assert.AreEqual('ROUTINE_LOCAL_TYPE_UNSUPPORTED',
        ReasonOf(lFacts.Bindings[0], 'A', 'unsupported'))
    else
      Assert.AreEqual('ALIAS_RECEIVER_MEMBERS_UNVERIFIED',
        ReasonOf(lFacts.Bindings[0], 'A', 'unsupported'));
  end else
    Assert.IsTrue(lHasMember, 'Alias field must bind to its receiver: ' + aShape);
  lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
  lSnapshotPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWithCompatibilitySnapshot(lFacts);
  if aMode = 'standalone' then
  begin
    lIdentity := Default(TDelphiSemanticSnapshotCacheIdentity);
    lIdentity.CacheKey := 'alias-receiver-proof';
    lIdentity.IdentityKey := lIdentity.CacheKey;
    lIdentity.SourceFileName := lOptions.ProjectFileName;
    lIdentity.FileHash := lFacts.ContextFingerprint;
    lIdentity.ContextHash := lFacts.ContextFingerprint;
    lIdentity.IncludeGraphHash := 'no-include-changes';
    lIdentity.SchemaVersion := 'alias-receiver-proof-v1';
    lStored := BuildCompatibilityRemoveWithPlanningSnapshotFromFacts(lFacts);
    try
      lCache := TDelphiSemanticSnapshotSqliteCache.Create(TPath.Combine(lRoot, 'standalone.sqlite'));
      try
        lCache.StoreProjectRemoveWithPlanningFacts(lIdentity, lStored, lFacts.Symbols);
        if (aShape = 'local-weak-var-globalA') then
        begin
          // DS-743: warm-unreachable (pre-existing guard: local receiver scope chain).
          Assert.IsFalse(lCache.TryLoadProjectRemoveWithPlanningFacts(lIdentity, lLoaded));
          Assert.IsTrue(lLoaded = nil);
          Assert.AreEqual(0, lCache.Metrics.CacheHits);
          Assert.AreEqual(1, lCache.Metrics.CacheMisses);
          Assert.AreEqual(1, lCache.Metrics.Invalidations);
          lSnapshotPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
        end else begin
          Assert.IsTrue(lCache.TryLoadProjectRemoveWithPlanningFacts(lIdentity, lLoaded));
          try
            Assert.AreEqual(1, lCache.Metrics.CacheHits);
            Assert.AreEqual(0, lCache.Metrics.CacheMisses);
            Assert.AreEqual(0, lCache.Metrics.Invalidations);
            lSnapshotPlan := TDelphiSemanticRemoveWithPlanner.Plan(lLoaded);
          finally
            lLoaded.Free;
          end;
        end;
      finally
        lCache.Free;
      end;
    finally
      lStored.Free;
    end;
  end;
  if MatchText(aMode, ['sessioncold', 'sessionwarm']) then
    for var i := 0 to Ord(aMode = 'sessionwarm') do
    begin
      lSession := TDelphiSemanticProjectSession.Open(ProjectOptionsFromApiOptions(lOptions));
      try
        Assert.IsTrue(lSession.Success);
        lSessionBuild := lSession.Session.PlanRemoveWithResult;
        if ((aShape = 'local-weak-var-globalA')) and (i = 1) then
        begin
          // DS-743 owns the unchanged loader guard; the session falls back to cold.
          Assert.AreEqual(0, lSessionBuild.SnapshotMetrics.SnapshotCacheHits);
          Assert.IsTrue(lSessionBuild.SnapshotMetrics.SnapshotCacheMisses > 0);
          Assert.IsTrue(lSessionBuild.SnapshotMetrics.SnapshotCacheInvalidations > 0);
        end else
          Assert.AreEqual(i, Integer(lSessionBuild.SnapshotMetrics.SnapshotCacheHits));
        lSnapshotPlan := lSessionBuild.Plan;
      finally
        lSession.Session.Free;
      end;
    end;
  GC(lSerializer, TJsonSerializer.Create, g);
  // Compatibility and snapshot planners intentionally identify their producer route.
  // The local standalone fallback is compared byte-for-byte without normalization.
  if lSnapshotPlan.BaselineSemanticModelVersion <> lPlan.BaselineSemanticModelVersion then
  begin
    Assert.AreEqual('project-snapshot-v1', lSnapshotPlan.BaselineSemanticModelVersion);
    lSnapshotPlan.BaselineSemanticModelVersion := lPlan.BaselineSemanticModelVersion;
  end;
  Assert.AreEqual(lSerializer.Serialize<TDelphiSemanticRemoveWithPlan>(lPlan),
    lSerializer.Serialize<TDelphiSemanticRemoveWithPlan>(lSnapshotPlan));
  Assert.AreEqual(lPlan.Status, lSnapshotPlan.Status);
  Assert.AreEqual(lPlan.ContextFingerprint, lSnapshotPlan.ContextFingerprint);
  Assert.AreEqual(Length(lPlan.Edits), Length(lSnapshotPlan.Edits));
  Assert.AreEqual(Length(lPlan.FinalStatements), Length(lSnapshotPlan.FinalStatements));
  for var i := 0 to High(lPlan.FinalStatements) do
  begin
    Assert.AreEqual(lPlan.FinalStatements[i].SemanticId, lSnapshotPlan.FinalStatements[i].SemanticId);
    Assert.AreEqual(lPlan.FinalStatements[i].Status, lSnapshotPlan.FinalStatements[i].Status);
    Assert.AreEqual(lPlan.FinalStatements[i].Reason, lSnapshotPlan.FinalStatements[i].Reason);
    Assert.AreEqual(lPlan.FinalStatements[i].SafetyReason, lSnapshotPlan.FinalStatements[i].SafetyReason);
    Assert.AreEqual(lPlan.FinalStatements[i].ReplacementText, lSnapshotPlan.FinalStatements[i].ReplacementText);
    Assert.AreEqual(Length(lPlan.FinalStatements[i].Temps), Length(lSnapshotPlan.FinalStatements[i].Temps));
    Assert.AreEqual(Length(lPlan.FinalStatements[i].Edits), Length(lSnapshotPlan.FinalStatements[i].Edits));
  end;
  if aMode <> 'cold' then
    lPlan := lSnapshotPlan;
  Assert.AreEqual(1, Integer(Length(lPlan.FinalStatements)));
  lStatement := lPlan.FinalStatements[0];
  if (not lRefused) and (not StartsText('strong-helper-', aShape)) and
    (not MatchText(aShape, ['strong-own-helper-global', 'fix-helper-via-plain'])) then
  begin
    Assert.AreEqual('planned', lStatement.Status, aShape + ': ' + lStatement.Reason);
    Assert.AreEqual(lExpected, lStatement.ReplacementText);
    if not MatchText(aShape, ['on-sib-a', 'd-nested-twoline-noconst']) then
      Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
    Exit;
  end;
  if aShape = 'fix-helper-via-plain' then
  begin
    Assert.AreEqual('skipped', lStatement.Status);
    Assert.AreEqual('receiver-member-unqualified', lStatement.Reason);
    Assert.AreEqual(0, Integer(Length(lPlan.Edits)));
    Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
    Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
    Assert.AreEqual('', lStatement.ReplacementText);
    Exit;
  end;
  Assert.AreEqual('skipped', lStatement.Status, aShape + ': ' + lStatement.Reason);
  if aShape = 'fix-local-strong' then
    Assert.AreEqual('ROUTINE_LOCAL_TYPE_UNSUPPORTED', lStatement.SafetyReason)
  else
    Assert.AreEqual('ALIAS_RECEIVER_MEMBERS_UNVERIFIED', lStatement.SafetyReason);
  Assert.AreEqual('', lStatement.ReplacementText);
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lPlan.Edits)));
end;

procedure TWithBinderTests.AliasCallsAndCapturedAliases(const aShape, aMode: string);
var
  lRoot, lSource, lExpected: string;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticApiOptions;
  lPlan, lSnapshotPlan: TDelphiSemanticRemoveWithPlan;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lStored, lLoaded: TDelphiProjectSnapshot;
  lSession: TDelphiSemanticProjectSessionResult;
  lSessionBuild: TDelphiSemanticRemoveWithPlanBuildResult;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
  lRefused: Boolean;
  lSerializer: TJsonSerializer;
  g: TGarbos;
begin
  lRoot := WithBinderTempPath('DS741-' + aShape + '-' + aMode);
  TDirectory.CreateDirectory(lRoot);
  lSource := '';
  if aShape = 'c-generic-alias-call-nongeneric-param' then
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'procedure Foo(X: Integer);'#13#10 +
      'type'#13#10 +
      ' TGen<T> = record'#13#10 +
      '  A: Integer;'#13#10 +
      '  procedure Foo(X: Integer);'#13#10 +
      ' end;'#13#10 +
      ' TIntRec = TGen<Integer>;'#13#10 +
      'var'#13#10 +
      ' Item: TIntRec;'#13#10 +
      ' G: Integer = 0;'#13#10 +
      'implementation'#13#10 +
      'procedure TGen<T>.Foo(X: Integer); begin A := X; end;'#13#10 +
      'procedure Foo(X: Integer); begin G := X; end;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' with Item do Foo(7);'#13#10 +
      ' Writeln(Item.A, '' '', G);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  if aShape = 'g-call-args' then
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'procedure Foo(X: Integer);'#13#10 +
      'function Get: Integer;'#13#10 +
      'type'#13#10 +
      ' TGen<T> = record'#13#10 +
      '  A: T;'#13#10 +
      '  procedure Foo(X: T);'#13#10 +
      '  function Get: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TIntRec = TGen<Integer>;'#13#10 +
      'var'#13#10 +
      ' Item: TIntRec;'#13#10 +
      ' G: Integer = 0;'#13#10 +
      ' A: Integer = 0;'#13#10 +
      'implementation'#13#10 +
      'procedure TGen<T>.Foo(X: T); begin A := X; end;'#13#10 +
      'function TGen<T>.Get: Integer; begin Result := 5; end;'#13#10 +
      'procedure Foo(X: Integer); begin G := X; end;'#13#10 +
      'function Get: Integer; begin Result := 100; end;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' with Item do Foo(7);'#13#10 +
      ' Writeln(Item.A, '' '', G, '' '', A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  if aShape = 'g-class-call' then
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'procedure Foo(X: Integer);'#13#10 +
      'function Get: Integer;'#13#10 +
      'type'#13#10 +
      ' TGen<T> = class'#13#10 +
      '  A: T;'#13#10 +
      '  procedure Foo(X: T);'#13#10 +
      '  function Get: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TIntC = TGen<Integer>;'#13#10 +
      'var'#13#10 +
      ' Item: TIntC;'#13#10 +
      ' G: Integer = 0;'#13#10 +
      ' A: Integer = 0;'#13#10 +
      'implementation'#13#10 +
      'procedure TGen<T>.Foo(X: T); begin A := X; end;'#13#10 +
      'function TGen<T>.Get: Integer; begin Result := 5; end;'#13#10 +
      'procedure Foo(X: Integer); begin G := X; end;'#13#10 +
      'function Get: Integer; begin Result := 100; end;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' Item := TIntC.Create;'#13#10 +
      ' with Item do Foo(7);'#13#10 +
      ' Writeln(Item.A, '' '', G, '' '', A);'#13#10 +
      ' Item.Free;'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  if aShape = 'g-escaped-call' then
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'procedure Foo(X: Integer);'#13#10 +
      'function Get: Integer;'#13#10 +
      'type'#13#10 +
      ' TGen<T> = record'#13#10 +
      '  A: T;'#13#10 +
      '  procedure Foo(X: T);'#13#10 +
      '  function Get: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TIntRec = TGen<Integer>;'#13#10 +
      ' TE = &TIntRec;'#13#10 +
      'var'#13#10 +
      ' Item: TE;'#13#10 +
      ' G: Integer = 0;'#13#10 +
      ' A: Integer = 0;'#13#10 +
      'implementation'#13#10 +
      'procedure TGen<T>.Foo(X: T); begin A := X; end;'#13#10 +
      'function TGen<T>.Get: Integer; begin Result := 5; end;'#13#10 +
      'procedure Foo(X: Integer); begin G := X; end;'#13#10 +
      'function Get: Integer; begin Result := 100; end;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' with Item do Foo(7);'#13#10 +
      ' Writeln(Item.A, '' '', G, '' '', A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  if aShape = 'k-b-call-helper-via-weak' then
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'procedure P(X: Integer);'#13#10 +
      'type'#13#10 +
      ' TRec = record'#13#10 +
      '  A: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TS = type TRec;'#13#10 +
      ' TS2 = TS;'#13#10 +
      ' THelp = record helper for TS2'#13#10 +
      '  procedure P(X: Integer);'#13#10 +
      ' end;'#13#10 +
      'var'#13#10 +
      ' Item: TS;'#13#10 +
      ' G: Integer = 0;'#13#10 +
      'implementation'#13#10 +
      'procedure THelp.P(X: Integer); begin A := X; end;'#13#10 +
      'procedure P(X: Integer); begin G := X; end;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' with Item do P(7);'#13#10 +
      ' Writeln(Item.A, '' '', G);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  if aShape = 'k-d3-call-own-helper' then
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'procedure P(X: Integer);'#13#10 +
      'type'#13#10 +
      ' TRec = record'#13#10 +
      '  A: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TS = type TRec;'#13#10 +
      ' THelp = record helper for TS'#13#10 +
      '  procedure P(X: Integer);'#13#10 +
      ' end;'#13#10 +
      'var'#13#10 +
      ' Item: TS;'#13#10 +
      ' G: Integer = 0;'#13#10 +
      'implementation'#13#10 +
      'procedure THelp.P(X: Integer); begin A := X; end;'#13#10 +
      'procedure P(X: Integer); begin G := X; end;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' with Item do P(7);'#13#10 +
      ' Writeln(Item.A, '' '', G);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  if aShape = 'k-d3-call-target-helper' then
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'procedure P(X: Integer);'#13#10 +
      'type'#13#10 +
      ' TRec = record'#13#10 +
      '  A: Integer;'#13#10 +
      ' end;'#13#10 +
      ' THelp = record helper for TRec'#13#10 +
      '  procedure P(X: Integer);'#13#10 +
      ' end;'#13#10 +
      ' TS = type TRec;'#13#10 +
      'var'#13#10 +
      ' Item: TS;'#13#10 +
      ' G: Integer = 0;'#13#10 +
      'implementation'#13#10 +
      'procedure THelp.P(X: Integer); begin A := X; end;'#13#10 +
      'procedure P(X: Integer); begin G := X; end;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' with Item do P(7);'#13#10 +
      ' Writeln(Item.A, '' '', G);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  if aShape = 'l-rtl-generic-alias-add' then
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses System.Generics.Collections;'#13#10 +
      'procedure Run;'#13#10 +
      'procedure Add(X: Integer);'#13#10 +
      'type'#13#10 +
      ' TIntList = TList<Integer>;'#13#10 +
      'var'#13#10 +
      ' L: TIntList;'#13#10 +
      ' G: Integer = 0;'#13#10 +
      'implementation'#13#10 +
      'procedure Add(X: Integer); begin G := X; end;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' L := TIntList.Create;'#13#10 +
      ' with L do Add(5);'#13#10 +
      ' Writeln(L.Count, '' '', G);'#13#10 +
      ' L.Free;'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  if aShape = 'c-plain-call' then
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'procedure Foo(X: Integer);'#13#10 +
      'type'#13#10 +
      ' TRec = record'#13#10 +
      '  A: Integer;'#13#10 +
      '  procedure Foo(X: Integer);'#13#10 +
      ' end;'#13#10 +
      'var'#13#10 +
      ' Item: TRec;'#13#10 +
      ' G: Integer = 0;'#13#10 +
      'implementation'#13#10 +
      'procedure TRec.Foo(X: Integer); begin A := X; end;'#13#10 +
      'procedure Foo(X: Integer); begin G := X; end;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' with Item do Foo(7);'#13#10 +
      ' Writeln(Item.A, '' '', G);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  if aShape = 'c-strong-call' then
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'procedure Foo(X: Integer);'#13#10 +
      'type'#13#10 +
      ' TRec = record'#13#10 +
      '  A: Integer;'#13#10 +
      '  procedure Foo(X: Integer);'#13#10 +
      ' end;'#13#10 +
      ' TS = type TRec;'#13#10 +
      'var'#13#10 +
      ' Item: TS;'#13#10 +
      ' G: Integer = 0;'#13#10 +
      'implementation'#13#10 +
      'procedure TRec.Foo(X: Integer); begin A := X; end;'#13#10 +
      'procedure Foo(X: Integer); begin G := X; end;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' with Item do Foo(7);'#13#10 +
      ' Writeln(Item.A, '' '', G);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  if aShape = 'c-weak-call' then
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'procedure Foo(X: Integer);'#13#10 +
      'type'#13#10 +
      ' TRec = record'#13#10 +
      '  A: Integer;'#13#10 +
      '  procedure Foo(X: Integer);'#13#10 +
      ' end;'#13#10 +
      ' TW = TRec;'#13#10 +
      'var'#13#10 +
      ' Item: TW;'#13#10 +
      ' G: Integer = 0;'#13#10 +
      'implementation'#13#10 +
      'procedure TRec.Foo(X: Integer); begin A := X; end;'#13#10 +
      'procedure Foo(X: Integer); begin G := X; end;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' with Item do Foo(7);'#13#10 +
      ' Writeln(Item.A, '' '', G);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  if aShape = 'k-weak-call-helper' then
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'procedure P(X: Integer);'#13#10 +
      'type'#13#10 +
      ' TRec = record'#13#10 +
      '  A: Integer;'#13#10 +
      ' end;'#13#10 +
      ' THelp = record helper for TRec'#13#10 +
      '  procedure P(X: Integer);'#13#10 +
      ' end;'#13#10 +
      ' TW = TRec;'#13#10 +
      'var'#13#10 +
      ' Item: TW;'#13#10 +
      ' G: Integer = 0;'#13#10 +
      'implementation'#13#10 +
      'procedure THelp.P(X: Integer); begin A := X; end;'#13#10 +
      'procedure P(X: Integer); begin G := X; end;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' with Item do P(7);'#13#10 +
      ' Writeln(Item.A, '' '', G);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  if aShape = 'nested-local-strong' then
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type TItem = record var A: Integer; end;'#13#10 +
      'var A: Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'type TA = type TItem;'#13#10 +
      'var Item: TA;'#13#10 +
      '  procedure Inner;'#13#10 +
      '  begin'#13#10 +
      '    with Item do A := 7;'#13#10 +
      '  end;'#13#10 +
      'begin'#13#10 +
      '  Item.A := 0;'#13#10 +
      '  Inner;'#13#10 +
      '  Writeln(Item.A, '' '', A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  if aShape = 'nested-local-weak' then
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type TItem = record var A: Integer; end;'#13#10 +
      'var A: Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'type TA = TItem;'#13#10 +
      'var Item: TA;'#13#10 +
      '  procedure Inner;'#13#10 +
      '  begin'#13#10 +
      '    with Item do A := 7;'#13#10 +
      '  end;'#13#10 +
      'begin'#13#10 +
      '  Item.A := 0;'#13#10 +
      '  Inner;'#13#10 +
      '  Writeln(Item.A, '' '', A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  lRefused := not MatchText(aShape, ['c-plain-call', 'c-strong-call', 'c-weak-call',
    'k-weak-call-helper', 'nested-local-weak']);
  lExpected := ' Item.Foo(7);';
  if aShape = 'c-plain-call' then
    lExpected :=       ' lWithRecPtr := @Item;'#13#10 +
      ' lWithRecPtr^.Foo(7);';
  if aShape = 'k-weak-call-helper' then
    lExpected := ' Item.P(7);';
  if aShape = 'nested-local-weak' then
    lExpected := ' Item.A := 7;';
  Assert.AreNotEqual('', lSource, aShape);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'), lSource, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P; uses Unit1; begin Run; end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dproj'),
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="Unit1.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.Combine(lRoot, 'P.dproj');
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win64';
  lOptions.DelphiVersion := '23.0';
  lOptions.Cache.SqliteCacheFileName := TPath.Combine(lRoot, 'cache.sqlite');
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
  lSnapshotPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWithCompatibilitySnapshot(lFacts);
  if aMode = 'standalone' then
  begin
    lIdentity := Default(TDelphiSemanticSnapshotCacheIdentity);
    lIdentity.CacheKey := 'alias-receiver-proof';
    lIdentity.IdentityKey := lIdentity.CacheKey;
    lIdentity.SourceFileName := lOptions.ProjectFileName;
    lIdentity.FileHash := lFacts.ContextFingerprint;
    lIdentity.ContextHash := lFacts.ContextFingerprint;
    lIdentity.IncludeGraphHash := 'no-include-changes';
    lIdentity.SchemaVersion := 'alias-receiver-proof-v1';
    lStored := BuildCompatibilityRemoveWithPlanningSnapshotFromFacts(lFacts);
    try
      lCache := TDelphiSemanticSnapshotSqliteCache.Create(TPath.Combine(lRoot, 'standalone.sqlite'));
      try
        lCache.StoreProjectRemoveWithPlanningFacts(lIdentity, lStored, lFacts.Symbols);
        if (aShape = 'nested-local-weak') then
        begin
          // DS-743: warm-unreachable (pre-existing guard: local receiver scope chain).
          Assert.IsFalse(lCache.TryLoadProjectRemoveWithPlanningFacts(lIdentity, lLoaded));
          Assert.IsTrue(lLoaded = nil);
          Assert.AreEqual(0, lCache.Metrics.CacheHits);
          Assert.AreEqual(1, lCache.Metrics.CacheMisses);
          Assert.AreEqual(1, lCache.Metrics.Invalidations);
          lSnapshotPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
        end else begin
          Assert.IsTrue(lCache.TryLoadProjectRemoveWithPlanningFacts(lIdentity, lLoaded));
          try
            Assert.AreEqual(1, lCache.Metrics.CacheHits);
            Assert.AreEqual(0, lCache.Metrics.CacheMisses);
            Assert.AreEqual(0, lCache.Metrics.Invalidations);
            lSnapshotPlan := TDelphiSemanticRemoveWithPlanner.Plan(lLoaded);
          finally
            lLoaded.Free;
          end;
        end;
      finally
        lCache.Free;
      end;
    finally
      lStored.Free;
    end;
  end;
  if MatchText(aMode, ['sessioncold', 'sessionwarm']) then
    for var i := 0 to Ord(aMode = 'sessionwarm') do
    begin
      lSession := TDelphiSemanticProjectSession.Open(ProjectOptionsFromApiOptions(lOptions));
      try
        Assert.IsTrue(lSession.Success);
        lSessionBuild := lSession.Session.PlanRemoveWithResult;
        if ((aShape = 'nested-local-weak')) and (i = 1) then
        begin
          // DS-743 owns the unchanged loader guard; the session falls back to cold.
          Assert.AreEqual(0, lSessionBuild.SnapshotMetrics.SnapshotCacheHits);
          Assert.IsTrue(lSessionBuild.SnapshotMetrics.SnapshotCacheMisses > 0);
          Assert.IsTrue(lSessionBuild.SnapshotMetrics.SnapshotCacheInvalidations > 0);
        end else
          Assert.AreEqual(i, Integer(lSessionBuild.SnapshotMetrics.SnapshotCacheHits));
        lSnapshotPlan := lSessionBuild.Plan;
      finally
        lSession.Session.Free;
      end;
    end;
  GC(lSerializer, TJsonSerializer.Create, g);
  // Compatibility and snapshot planners intentionally identify their producer route.
  // The local standalone fallback is compared byte-for-byte without normalization.
  if lSnapshotPlan.BaselineSemanticModelVersion <> lPlan.BaselineSemanticModelVersion then
  begin
    Assert.AreEqual('project-snapshot-v1', lSnapshotPlan.BaselineSemanticModelVersion);
    lSnapshotPlan.BaselineSemanticModelVersion := lPlan.BaselineSemanticModelVersion;
  end;
  Assert.AreEqual(lSerializer.Serialize<TDelphiSemanticRemoveWithPlan>(lPlan),
    lSerializer.Serialize<TDelphiSemanticRemoveWithPlan>(lSnapshotPlan));
  Assert.AreEqual(lPlan.Status, lSnapshotPlan.Status);
  Assert.AreEqual(lPlan.ContextFingerprint, lSnapshotPlan.ContextFingerprint);
  Assert.AreEqual(Length(lPlan.Edits), Length(lSnapshotPlan.Edits));
  Assert.AreEqual(Length(lPlan.FinalStatements), Length(lSnapshotPlan.FinalStatements));
  for var i := 0 to High(lPlan.FinalStatements) do
  begin
    Assert.AreEqual(lPlan.FinalStatements[i].SemanticId, lSnapshotPlan.FinalStatements[i].SemanticId);
    Assert.AreEqual(lPlan.FinalStatements[i].Status, lSnapshotPlan.FinalStatements[i].Status);
    Assert.AreEqual(lPlan.FinalStatements[i].Reason, lSnapshotPlan.FinalStatements[i].Reason);
    Assert.AreEqual(lPlan.FinalStatements[i].SafetyReason, lSnapshotPlan.FinalStatements[i].SafetyReason);
    Assert.AreEqual(lPlan.FinalStatements[i].ReplacementText, lSnapshotPlan.FinalStatements[i].ReplacementText);
    Assert.AreEqual(Length(lPlan.FinalStatements[i].Temps), Length(lSnapshotPlan.FinalStatements[i].Temps));
    Assert.AreEqual(Length(lPlan.FinalStatements[i].Edits), Length(lSnapshotPlan.FinalStatements[i].Edits));
  end;
  if aMode <> 'cold' then
    lPlan := lSnapshotPlan;
  Assert.AreEqual(1, Integer(Length(lPlan.FinalStatements)));
  lStatement := lPlan.FinalStatements[0];
  if not lRefused then
  begin
    Assert.AreEqual('planned', lStatement.Status, aShape + ': ' + lStatement.Reason);
    Assert.AreEqual(lExpected, lStatement.ReplacementText);
    Assert.AreEqual(1 + Ord(aShape = 'c-plain-call'), Integer(Length(lStatement.Edits)));
    Exit;
  end;
  Assert.AreEqual('skipped', lStatement.Status, aShape + ': ' + lStatement.Reason);
  if aShape = 'nested-local-strong' then
    Assert.AreEqual('ROUTINE_LOCAL_TYPE_UNSUPPORTED', lStatement.SafetyReason)
  else
    Assert.AreEqual('ALIAS_RECEIVER_MEMBERS_UNVERIFIED', lStatement.SafetyReason);
  Assert.AreEqual('', lStatement.ReplacementText);
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
  Assert.AreEqual(0, Integer(Length(lPlan.Edits)));
end;

procedure TWithBinderTests.IdenticalReceiverExceptionNegativeControls(
  const aShape, aMode: string);
begin
  AliasFallbackAndForwardScopes(aShape, aMode);
end;

procedure TWithBinderTests.AliasFallbackAndForwardScopes(const aShape, aMode: string);
var
  lRoot, lSource, lSecondSource, lExpected: string;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticApiOptions;
  lPlan, lSnapshotPlan: TDelphiSemanticRemoveWithPlan;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lStored, lLoaded: TDelphiProjectSnapshot;
  lSession: TDelphiSemanticProjectSessionResult;
  lSessionBuild: TDelphiSemanticRemoveWithPlanBuildResult;
  lStatement, lInnerStatement: TDelphiSemanticRemoveWithFinalStatement;
  lRefused, lLocal, lWarmUnreachable, lProjectionFound: Boolean;
  lSymbol: TDelphiSemanticInventorySymbol;
  lExpectedEdits, lExpectedLine, lExpectedColumn: Integer;
  lSerializer: TJsonSerializer;
  g: TGarbos;
begin
  lRoot := WithBinderTempPath('DS741-' + aShape + '-' + aMode);
  TDirectory.CreateDirectory(lRoot);
  lSource := '';
  lSecondSource := '';
  lExpected := '';
  lRefused := True;
  lLocal := False;
  lExpectedEdits := 0;
  lExpectedLine := 0;
  lExpectedColumn := 0;
  if aShape = 'r4-x1-strong-excludeattr' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses System.SysUtils, Winapi.Windows;'#13#10 +
      'type'#13#10 +
      ' TMySR = type TSearchRec;'#13#10 +
      'var'#13#10 +
      ' G: Integer = 0;'#13#10 +
      ' ExcludeAttr: Integer = 0;'#13#10 +
      'procedure Run;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'var SR: TMySR;'#13#10 +
      'begin'#13#10 +
      '  SR := Default(TMySR);'#13#10 +
      '  SR.Name := ''abc'';'#13#10 +
      '  with SR do'#13#10 +
      '  begin'#13#10 +
      '    ExcludeAttr := 7;'#13#10 +
      '  end;'#13#10 +
      '  Writeln(SR.ExcludeAttr, '' '', ExcludeAttr);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    lRefused := True;
    lExpectedEdits := 1;
    lExpectedLine := 16;
    lExpectedColumn := 3;
  end;
  if aShape = 'r4-x3-weak-of-strong-excl' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses System.SysUtils, Winapi.Windows;'#13#10 +
      'type'#13#10 +
      ' TS = type TSearchRec;'#13#10 +
      ' TMySR = TS;'#13#10 +
      'var'#13#10 +
      ' G: Integer = 0;'#13#10 +
      ' ExcludeAttr: Integer = 0;'#13#10 +
      'procedure Run;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'var SR: TMySR;'#13#10 +
      'begin'#13#10 +
      '  SR := Default(TMySR);'#13#10 +
      '  SR.Name := ''abc'';'#13#10 +
      '  with SR do'#13#10 +
      '  begin'#13#10 +
      '    ExcludeAttr := 7;'#13#10 +
      '  end;'#13#10 +
      '  Writeln(SR.ExcludeAttr, '' '', ExcludeAttr);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    lRefused := True;
    lExpectedEdits := 1;
    lExpectedLine := 17;
    lExpectedColumn := 3;
  end;
  if aShape = 'r4-x7-strong-name-plain' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses System.SysUtils, Winapi.Windows;'#13#10 +
      'type'#13#10 +
      ' TMySR = type TSearchRec;'#13#10 +
      'var'#13#10 +
      ' G: Integer = 0;'#13#10 +
      ' Name: string = ''g'';'#13#10 +
      'procedure Run;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'var SR: TMySR;'#13#10 +
      'begin'#13#10 +
      '  SR := Default(TMySR);'#13#10 +
      '  SR.Name := ''abc'';'#13#10 +
      '  with SR do'#13#10 +
      '  begin'#13#10 +
      '    Name := ''x'';'#13#10 +
      '  end;'#13#10 +
      '  Writeln(SR.Name, '' '', Name);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    lRefused := True;
    lExpectedEdits := 1;
    lExpectedLine := 16;
    lExpectedColumn := 3;
  end;
  if aShape = 'r4-x8-strong-size-plain' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses System.SysUtils, Winapi.Windows;'#13#10 +
      'type'#13#10 +
      ' TMySR = type TSearchRec;'#13#10 +
      'var'#13#10 +
      ' G: Integer = 0;'#13#10 +
      ' Size: Int64 = 1;'#13#10 +
      'procedure Run;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'var SR: TMySR;'#13#10 +
      'begin'#13#10 +
      '  SR := Default(TMySR);'#13#10 +
      '  SR.Name := ''abc'';'#13#10 +
      '  with SR do'#13#10 +
      '  begin'#13#10 +
      '    Size := 5;'#13#10 +
      '  end;'#13#10 +
      '  Writeln(SR.Size, '' '', Size);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    lRefused := True;
    lExpectedEdits := 1;
    lExpectedLine := 16;
    lExpectedColumn := 3;
  end;
  if aShape = 'r4-x9-weak-of-strong-name' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses System.SysUtils, Winapi.Windows;'#13#10 +
      'type'#13#10 +
      ' TS = type TSearchRec;'#13#10 +
      ' TMySR = TS;'#13#10 +
      'var'#13#10 +
      ' G: Integer = 0;'#13#10 +
      ' Name: string = ''g'';'#13#10 +
      'procedure Run;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'var SR: TMySR;'#13#10 +
      'begin'#13#10 +
      '  SR := Default(TMySR);'#13#10 +
      '  SR.Name := ''abc'';'#13#10 +
      '  with SR do'#13#10 +
      '  begin'#13#10 +
      '    Name := ''x'';'#13#10 +
      '  end;'#13#10 +
      '  Writeln(SR.Name, '' '', Name);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    lRefused := True;
    lExpectedEdits := 1;
    lExpectedLine := 17;
    lExpectedColumn := 3;
  end;
  if aShape = 'r4-weak-name-plain' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses System.SysUtils, Winapi.Windows;'#13#10 +
      'type'#13#10 +
      ' TMySR = TSearchRec;'#13#10 +
      'var'#13#10 +
      ' G: Integer = 0;'#13#10 +
      ' Name: string = ''g'';'#13#10 +
      'procedure Run;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'var SR: TMySR;'#13#10 +
      'begin'#13#10 +
      '  SR := Default(TMySR);'#13#10 +
      '  SR.Name := ''abc'';'#13#10 +
      '  with SR do'#13#10 +
      '  begin'#13#10 +
      '    Name := ''x'';'#13#10 +
      '  end;'#13#10 +
      '  Writeln(SR.Name, '' '', Name);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    lRefused := False;
    lExpected := '  begin'#13#10 +
      '    SR.Name := ''x'';'#13#10 +
      '  end;';
    lExpectedEdits := 1;
    lExpectedLine := 16;
    lExpectedColumn := 3;
  end;
  if aShape = 'r4-weak-size-plain' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses System.SysUtils, Winapi.Windows;'#13#10 +
      'type'#13#10 +
      ' TMySR = TSearchRec;'#13#10 +
      'var'#13#10 +
      ' G: Integer = 0;'#13#10 +
      ' Size: Int64 = 1;'#13#10 +
      'procedure Run;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'var SR: TMySR;'#13#10 +
      'begin'#13#10 +
      '  SR := Default(TMySR);'#13#10 +
      '  SR.Name := ''abc'';'#13#10 +
      '  with SR do'#13#10 +
      '  begin'#13#10 +
      '    Size := 5;'#13#10 +
      '  end;'#13#10 +
      '  Writeln(SR.Size, '' '', Size);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    lRefused := False;
    lExpected := '  begin'#13#10 +
      '    SR.Size := 5;'#13#10 +
      '  end;';
    lExpectedEdits := 1;
    lExpectedLine := 16;
    lExpectedColumn := 3;
  end;
  if MatchText(aShape, ['rtl-weak-homonym', 'rtl-weak-chain-homonym', 'rtl-strong-homonym']) then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses System.SysUtils;'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TA = TSearchRec;'#13#10 +
      'var Item: TA;'#13#10 +
      ' Name: string;'#13#10 +
      ' Bytes: array[0..1] of Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' Name := ''global'';'#13#10 +
      ' Item.Name := ''before'';'#13#10 +
      ' with Item do begin Name := ''receiver''; Bytes[1] := Length(Name); end;'#13#10 +
      ' Writeln(Item.Name, '' '', Name, '' '', Bytes[1]);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    lRefused := aShape = 'rtl-strong-homonym';
    if lRefused then
      lSource := StringReplace(lSource, 'TA = TSearchRec;', 'TA = type TSearchRec;', []);
    lExpected := ' begin Item.Name := ''receiver''; Bytes[1] := Length(Item.Name); end;';
    lExpectedEdits := 1;
    lExpectedLine := 15;
    lExpectedColumn := 2;
    if aShape = 'rtl-weak-chain-homonym' then
    begin
      lSource := StringReplace(lSource, 'var Item: TA;', ' TB = TA;'#13#10'var Item: TB;', []);
      lExpectedLine := 16;
    end;
  end;
  if aShape = 'opus-e7-forward-nested-strong' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TItem = record'#13#10 +
      '  A: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TOther = record'#13#10 +
      '  B: Integer;'#13#10 +
      ' end;'#13#10 +
      'var'#13#10 +
      ' A: Integer = 0;'#13#10 +
      ' B: Integer = 0;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'type TA = type TItem;'#13#10 +
      'var Item: TA;'#13#10 +
      '  procedure Inner; forward;'#13#10 +
      '  procedure Other;'#13#10 +
      '  begin'#13#10 +
      '    Inner;'#13#10 +
      '  end;'#13#10 +
      '  procedure Inner;'#13#10 +
      '  begin'#13#10 +
      '    with Item do A := 7;'#13#10 +
      '  end;'#13#10 +
      'begin'#13#10 +
      '  Item.A := 0;'#13#10 +
      '  Other;'#13#10 +
      '  Writeln(Item.A, '' '', A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := True;
    lLocal := True;
    lExpected := ' A := 7;';
    lExpectedEdits := 1;
    lExpectedLine := 25;
    lExpectedColumn := 5;
  end;
  if aShape = 'opus-e14-forward-two-level-strong' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TItem = record'#13#10 +
      '  A: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TOther = record'#13#10 +
      '  B: Integer;'#13#10 +
      ' end;'#13#10 +
      'var'#13#10 +
      ' A: Integer = 0;'#13#10 +
      ' B: Integer = 0;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'type TA = type TItem;'#13#10 +
      'var Item: TA;'#13#10 +
      '  procedure Mid; forward;'#13#10 +
      '  procedure Other;'#13#10 +
      '  begin'#13#10 +
      '    Mid;'#13#10 +
      '  end;'#13#10 +
      '  procedure Mid;'#13#10 +
      '    procedure Inner;'#13#10 +
      '    begin'#13#10 +
      '      with Item do A := 7;'#13#10 +
      '    end;'#13#10 +
      '  begin'#13#10 +
      '    Inner;'#13#10 +
      '  end;'#13#10 +
      'begin'#13#10 +
      '  Item.A := 0;'#13#10 +
      '  Other;'#13#10 +
      '  Writeln(Item.A, '' '', A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := True;
    lLocal := True;
    lExpected := ' A := 7;';
    lExpectedEdits := 1;
    lExpectedLine := 26;
    lExpectedColumn := 7;
  end;
  if aShape = 'opus-h1-field-array-s' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TSub = record S: Integer; end;'#13#10 +
      ' TItem = record'#13#10 +
      '  A: Integer;'#13#10 +
      '  Arr: array[0..1] of Integer;'#13#10 +
      '  Sub: TSub;'#13#10 +
      ' end;'#13#10 +
      'type'#13#10 +
      ' TX = type TItem;'#13#10 +
      'var'#13#10 +
      ' Item: TX;'#13#10 +
      ' G: Integer = 0;'#13#10 +
      ' Arr: array[0..1] of Integer = (40, 41);'#13#10 +
      ' Sub: TSub;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' Item.Arr[1] := 21; Item.Sub.S := 5; Sub.S := 50;'#13#10 +
      ' with Item do G := Arr[1];'#13#10 +
      ' Writeln(G);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := True;
    lLocal := False;
    lExpected := ' G := Arr[1];';
    lExpectedEdits := 1;
    lExpectedLine := 22;
    lExpectedColumn := 2;
  end;
  if aShape = 'opus-h2-dotted-field-s' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TSub = record S: Integer; end;'#13#10 +
      ' TItem = record'#13#10 +
      '  A: Integer;'#13#10 +
      '  Arr: array[0..1] of Integer;'#13#10 +
      '  Sub: TSub;'#13#10 +
      ' end;'#13#10 +
      'type'#13#10 +
      ' TX = type TItem;'#13#10 +
      'var'#13#10 +
      ' Item: TX;'#13#10 +
      ' G: Integer = 0;'#13#10 +
      ' Arr: array[0..1] of Integer = (40, 41);'#13#10 +
      ' Sub: TSub;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' Item.Arr[1] := 21; Item.Sub.S := 5; Sub.S := 50;'#13#10 +
      ' with Item do G := Sub.S;'#13#10 +
      ' Writeln(G);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := True;
    lLocal := False;
    lExpected := ' G := Sub.S;';
    lExpectedEdits := 1;
    lExpectedLine := 22;
    lExpectedColumn := 2;
  end;
  if aShape = 'opus-h3-dotted-write-s' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TSub = record S: Integer; end;'#13#10 +
      ' TItem = record'#13#10 +
      '  A: Integer;'#13#10 +
      '  Arr: array[0..1] of Integer;'#13#10 +
      '  Sub: TSub;'#13#10 +
      ' end;'#13#10 +
      'type'#13#10 +
      ' TX = type TItem;'#13#10 +
      'var'#13#10 +
      ' Item: TX;'#13#10 +
      ' G: Integer = 0;'#13#10 +
      ' Arr: array[0..1] of Integer = (40, 41);'#13#10 +
      ' Sub: TSub;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' Item.Arr[1] := 21; Item.Sub.S := 5; Sub.S := 50;'#13#10 +
      ' with Item do Sub.S := 9; G := Item.Sub.S * 100 + Sub.S;'#13#10 +
      ' Writeln(G);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := True;
    lLocal := False;
    lExpected := ' Sub.S := 9;';
    lExpectedEdits := 1;
    lExpectedLine := 22;
    lExpectedColumn := 2;
  end;
  if aShape = 'opus-c5-indexed-default-s2' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'procedure Foo(X: Integer); overload;'#13#10 +
      'function Get: Integer;'#13#10 +
      'function P: Integer;'#13#10 +
      'const STR = ''xy'';'#13#10 +
      'type'#13#10 +
      ' TSub = record'#13#10 +
      '  S: Integer;'#13#10 +
      '  procedure Foo(X: Integer);'#13#10 +
      ' end;'#13#10 +
      ' TItem = record'#13#10 +
      '  A: Integer;'#13#10 +
      '  B: Integer;'#13#10 +
      '  Sub: TSub;'#13#10 +
      '  procedure Foo(X: Integer); overload;'#13#10 +
      '  procedure Foo(const X: string); overload;'#13#10 +
      '  function Get: Integer;'#13#10 +
      '  function GetP: Integer;'#13#10 +
      '  function GetItem(I: Integer): Integer;'#13#10 +
      '  property P: Integer read GetP;'#13#10 +
      '  property Items[I: Integer]: Integer read GetItem; default;'#13#10 +
      ' end;'#13#10 +
      ' TGen<T> = record'#13#10 +
      '  A: T;'#13#10 +
      '  B: T;'#13#10 +
      '  Sub: TSub;'#13#10 +
      '  procedure Foo(X: T); overload;'#13#10 +
      '  procedure Foo(const X: string); overload;'#13#10 +
      '  function Get: Integer;'#13#10 +
      '  function GetP: Integer;'#13#10 +
      '  function GetItem(I: Integer): Integer;'#13#10 +
      '  property P: Integer read GetP;'#13#10 +
      '  property Items[I: Integer]: Integer read GetItem; default;'#13#10 +
      ' end;'#13#10 +
      'type'#13#10 +
      ' TX = type TItem;'#13#10 +
      'var'#13#10 +
      ' Item: TX;'#13#10 +
      ' A: Integer = 0;'#13#10 +
      ' B: Integer = 4;'#13#10 +
      ' G: Integer = 0;'#13#10 +
      ' Items: array[0..1] of Integer = (40, 41);'#13#10 +
      'implementation'#13#10 +
      'procedure TSub.Foo(X: Integer); begin S := X; end;'#13#10 +
      'procedure TItem.Foo(X: Integer); begin A := X; end;'#13#10 +
      'procedure TItem.Foo(const X: string); begin A := A + Length(X) + 10; end;'#13#10 +
      'function TItem.Get: Integer; begin Result := 5; end;'#13#10 +
      'function TItem.GetP: Integer; begin Result := 6; end;'#13#10 +
      'function TItem.GetItem(I: Integer): Integer; begin Result := 20 + I; end;'#13#10 +
      'procedure TGen<T>.Foo(X: T); begin A := X; end;'#13#10 +
      'procedure TGen<T>.Foo(const X: string); begin end;'#13#10 +
      'function TGen<T>.Get: Integer; begin Result := 5; end;'#13#10 +
      'function TGen<T>.GetP: Integer; begin Result := 6; end;'#13#10 +
      'function TGen<T>.GetItem(I: Integer): Integer; begin Result := 20 + I; end;'#13#10 +
      'procedure Foo(X: Integer); begin G := X; end;'#13#10 +
      'function Get: Integer; begin Result := 100; end;'#13#10 +
      'function P: Integer; begin Result := 200; end;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' Item.A := 0; Item.B := 3; Item.Sub.S := 0;'#13#10 +
      ' with Item do G := Items[1];'#13#10 +
      ' Writeln(Item.A, '' '', Item.Sub.S, '' '', G, '' '', A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := True;
    lLocal := False;
    lExpected := ' G := Items[1];';
    lExpectedEdits := 1;
    lExpectedLine := 63;
    lExpectedColumn := 2;
  end;
  if aShape = 'opus-c1-args-members-s2' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'procedure Foo(X: Integer); overload;'#13#10 +
      'function Get: Integer;'#13#10 +
      'function P: Integer;'#13#10 +
      'const STR = ''xy'';'#13#10 +
      'type'#13#10 +
      ' TSub = record'#13#10 +
      '  S: Integer;'#13#10 +
      '  procedure Foo(X: Integer);'#13#10 +
      ' end;'#13#10 +
      ' TItem = record'#13#10 +
      '  A: Integer;'#13#10 +
      '  B: Integer;'#13#10 +
      '  Sub: TSub;'#13#10 +
      '  procedure Foo(X: Integer); overload;'#13#10 +
      '  procedure Foo(const X: string); overload;'#13#10 +
      '  function Get: Integer;'#13#10 +
      '  function GetP: Integer;'#13#10 +
      '  function GetItem(I: Integer): Integer;'#13#10 +
      '  property P: Integer read GetP;'#13#10 +
      '  property Items[I: Integer]: Integer read GetItem; default;'#13#10 +
      ' end;'#13#10 +
      ' TGen<T> = record'#13#10 +
      '  A: T;'#13#10 +
      '  B: T;'#13#10 +
      '  Sub: TSub;'#13#10 +
      '  procedure Foo(X: T); overload;'#13#10 +
      '  procedure Foo(const X: string); overload;'#13#10 +
      '  function Get: Integer;'#13#10 +
      '  function GetP: Integer;'#13#10 +
      '  function GetItem(I: Integer): Integer;'#13#10 +
      '  property P: Integer read GetP;'#13#10 +
      '  property Items[I: Integer]: Integer read GetItem; default;'#13#10 +
      ' end;'#13#10 +
      'type'#13#10 +
      ' TX = type TItem;'#13#10 +
      'var'#13#10 +
      ' Item: TX;'#13#10 +
      ' A: Integer = 0;'#13#10 +
      ' B: Integer = 4;'#13#10 +
      ' G: Integer = 0;'#13#10 +
      ' Items: array[0..1] of Integer = (40, 41);'#13#10 +
      'implementation'#13#10 +
      'procedure TSub.Foo(X: Integer); begin S := X; end;'#13#10 +
      'procedure TItem.Foo(X: Integer); begin A := X; end;'#13#10 +
      'procedure TItem.Foo(const X: string); begin A := A + Length(X) + 10; end;'#13#10 +
      'function TItem.Get: Integer; begin Result := 5; end;'#13#10 +
      'function TItem.GetP: Integer; begin Result := 6; end;'#13#10 +
      'function TItem.GetItem(I: Integer): Integer; begin Result := 20 + I; end;'#13#10 +
      'procedure TGen<T>.Foo(X: T); begin A := X; end;'#13#10 +
      'procedure TGen<T>.Foo(const X: string); begin end;'#13#10 +
      'function TGen<T>.Get: Integer; begin Result := 5; end;'#13#10 +
      'function TGen<T>.GetP: Integer; begin Result := 6; end;'#13#10 +
      'function TGen<T>.GetItem(I: Integer): Integer; begin Result := 20 + I; end;'#13#10 +
      'procedure Foo(X: Integer); begin G := X; end;'#13#10 +
      'function Get: Integer; begin Result := 100; end;'#13#10 +
      'function P: Integer; begin Result := 200; end;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' Item.A := 0; Item.B := 3; Item.Sub.S := 0;'#13#10 +
      ' with Item do Foo(B);'#13#10 +
      ' Writeln(Item.A, '' '', Item.Sub.S, '' '', G, '' '', A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := True;
    lLocal := False;
    lExpected := ' Foo(Item.B);';
    lExpectedEdits := 1;
    lExpectedLine := 63;
    lExpectedColumn := 2;
  end;
  if aShape = 'opus-f5-strong-chain-overload-call' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'procedure Foo(X: Integer); overload;'#13#10 +
      'function Get: Integer;'#13#10 +
      'function P: Integer;'#13#10 +
      'const STR = ''xy'';'#13#10 +
      'type'#13#10 +
      ' TSub = record'#13#10 +
      '  S: Integer;'#13#10 +
      '  procedure Foo(X: Integer);'#13#10 +
      ' end;'#13#10 +
      ' TItem = record'#13#10 +
      '  A: Integer;'#13#10 +
      '  B: Integer;'#13#10 +
      '  Sub: TSub;'#13#10 +
      '  procedure Foo(X: Integer); overload;'#13#10 +
      '  procedure Foo(const X: string); overload;'#13#10 +
      '  function Get: Integer;'#13#10 +
      '  function GetP: Integer;'#13#10 +
      '  function GetItem(I: Integer): Integer;'#13#10 +
      '  property P: Integer read GetP;'#13#10 +
      '  property Items[I: Integer]: Integer read GetItem; default;'#13#10 +
      ' end;'#13#10 +
      ' TGen<T> = record'#13#10 +
      '  A: T;'#13#10 +
      '  B: T;'#13#10 +
      '  Sub: TSub;'#13#10 +
      '  procedure Foo(X: T); overload;'#13#10 +
      '  procedure Foo(const X: string); overload;'#13#10 +
      '  function Get: Integer;'#13#10 +
      '  function GetP: Integer;'#13#10 +
      '  function GetItem(I: Integer): Integer;'#13#10 +
      '  property P: Integer read GetP;'#13#10 +
      '  property Items[I: Integer]: Integer read GetItem; default;'#13#10 +
      ' end;'#13#10 +
      'type'#13#10 +
      ' TY = type TItem;'#13#10 +
      ' TX = TY;'#13#10 +
      'var'#13#10 +
      ' Item: TX;'#13#10 +
      ' A: Integer = 0;'#13#10 +
      ' B: Integer = 4;'#13#10 +
      ' G: Integer = 0;'#13#10 +
      ' Items: array[0..1] of Integer = (40, 41);'#13#10 +
      'implementation'#13#10 +
      'procedure TSub.Foo(X: Integer); begin S := X; end;'#13#10 +
      'procedure TItem.Foo(X: Integer); begin A := X; end;'#13#10 +
      'procedure TItem.Foo(const X: string); begin A := A + Length(X) + 10; end;'#13#10 +
      'function TItem.Get: Integer; begin Result := 5; end;'#13#10 +
      'function TItem.GetP: Integer; begin Result := 6; end;'#13#10 +
      'function TItem.GetItem(I: Integer): Integer; begin Result := 20 + I; end;'#13#10 +
      'procedure TGen<T>.Foo(X: T); begin A := X; end;'#13#10 +
      'procedure TGen<T>.Foo(const X: string); begin end;'#13#10 +
      'function TGen<T>.Get: Integer; begin Result := 5; end;'#13#10 +
      'function TGen<T>.GetP: Integer; begin Result := 6; end;'#13#10 +
      'function TGen<T>.GetItem(I: Integer): Integer; begin Result := 20 + I; end;'#13#10 +
      'procedure Foo(X: Integer); begin G := X; end;'#13#10 +
      'function Get: Integer; begin Result := 100; end;'#13#10 +
      'function P: Integer; begin Result := 200; end;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' Item.A := 0; Item.B := 3; Item.Sub.S := 0;'#13#10 +
      ' with Item do Foo(B);'#13#10 +
      ' Writeln(Item.A, '' '', Item.Sub.S, '' '', G, '' '', A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := True;
    lLocal := False;
    lExpected := ' Foo(Item.B);';
    lExpectedEdits := 1;
    lExpectedLine := 64;
    lExpectedColumn := 2;
  end;
  if aShape = 'sol-forward-captured-strong' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type TItem = record var A: Integer; end;'#13#10 +
      'var A: Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'type TA = type TItem;'#13#10 +
      'var Item: TA;'#13#10 +
      'procedure Inner; forward;'#13#10 +
      'procedure Inner;'#13#10 +
      'begin with Item do A := 7; end;'#13#10 +
      'begin'#13#10 +
      'Item.A := 0;'#13#10 +
      ' Inner;'#13#10 +
      ' Writeln(Item.A, '' '', A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := True;
    lLocal := True;
    lExpected := ' A := 7;';
    lExpectedEdits := 1;
    lExpectedLine := 12;
    lExpectedColumn := 7;
  end;
  if aShape = 'sol-forward-late-strong' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type TItem = record var A: Integer; end;'#13#10 +
      'var A: Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'procedure Inner; forward;'#13#10 +
      'type TA = type TItem;'#13#10 +
      'var Item: TA;'#13#10 +
      'procedure Inner;'#13#10 +
      'begin with Item do A := 7; end;'#13#10 +
      'begin'#13#10 +
      'Item.A := 0;'#13#10 +
      ' Inner;'#13#10 +
      ' Writeln(Item.A, '' '', A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := True;
    lLocal := True;
    lExpected := ' A := 7;';
    lExpectedEdits := 1;
    lExpectedLine := 12;
    lExpectedColumn := 7;
  end;
  if aShape = 'sol-clean-strong-overload' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TRec = record'#13#10 +
      '  A: Integer;'#13#10 +
      '  procedure Foo(X: Integer); overload;'#13#10 +
      ' procedure Foo(const X: string); overload;'#13#10 +
      '  function Get: Integer;'#13#10 +
      '  function GetAt(Index: Integer): Integer;'#13#10 +
      '  procedure SetAt(Index, Value: Integer);'#13#10 +
      '  property Value: Integer read Get;'#13#10 +
      '  property Values[Index: Integer]: Integer read GetAt write SetAt; default;'#13#10 +
      ' end;'#13#10 +
      ''#13#10 +
      ' TA = type TRec;'#13#10 +
      ''#13#10 +
      'var'#13#10 +
      ' Item: TA;'#13#10 +
      ' A: Integer;'#13#10 +
      ' G: Integer;'#13#10 +
      ' Values: array[0..1] of Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure TRec.Foo(X: Integer); begin A := X; end;'#13#10 +
      'procedure TRec.Foo(const X: string); begin A := 9; end;'#13#10 +
      ''#13#10 +
      'function TRec.Get: Integer; begin Result := 5; end;'#13#10 +
      'function TRec.GetAt(Index: Integer): Integer; begin Result := A + Index; end;'#13#10 +
      'procedure TRec.SetAt(Index, Value: Integer); begin A := Value + Index; end;'#13#10 +
      'procedure Foo(X: Integer); begin G := X; end;'#13#10 +
      'function Get: Integer; begin Result := 100; end;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' Item.A := 3;'#13#10 +
      ' A := 100;'#13#10 +
      ' with Item do Foo(7);'#13#10 +
      ' Writeln(Item.A, '' '', A, '' '', G, '' '', Values[0]);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := True;
    lLocal := False;
    lExpected := ' Foo(7);';
    lExpectedEdits := 1;
    lExpectedLine := 36;
    lExpectedColumn := 2;
  end;
  if aShape = 'sol-getter-property-call-strong' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TProc = procedure(X: Integer);'#13#10 +
      ' TRec = record'#13#10 +
      '  Handler: TProc;'#13#10 +
      '  function GetProc: TProc;'#13#10 +
      '  property P: TProc read GetProc;'#13#10 +
      ' end;'#13#10 +
      ''#13#10 +
      ' TA = type TRec;'#13#10 +
      ''#13#10 +
      'var'#13#10 +
      ' Item: TA;'#13#10 +
      ' Hit: Integer;'#13#10 +
      ' G: Integer;'#13#10 +
      'implementation'#13#10 +
      'function TRec.GetProc: TProc; begin Result := Handler; end;'#13#10 +
      'procedure P(X: Integer); begin G := X; end;'#13#10 +
      'procedure Target(X: Integer); begin Hit := X; end;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' Item.Handler := Target;'#13#10 +
      ' with Item do P(7);'#13#10 +
      ' Writeln(Hit, '' '', G);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := True;
    lLocal := False;
    lExpected := ' P(7);';
    lExpectedEdits := 1;
    lExpectedLine := 25;
    lExpectedColumn := 2;
  end;
  if aShape = 'sol-clean-strong-indexed-read' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TRec = record'#13#10 +
      '  A: Integer;'#13#10 +
      '  procedure Foo(X: Integer);'#13#10 +
      '  function Get: Integer;'#13#10 +
      '  function GetAt(Index: Integer): Integer;'#13#10 +
      '  procedure SetAt(Index, Value: Integer);'#13#10 +
      '  property Value: Integer read Get;'#13#10 +
      '  property Values[Index: Integer]: Integer read GetAt write SetAt; default;'#13#10 +
      ' end;'#13#10 +
      ''#13#10 +
      ' TA = type TRec;'#13#10 +
      ''#13#10 +
      'var'#13#10 +
      ' Item: TA;'#13#10 +
      ' A: Integer;'#13#10 +
      ' G: Integer;'#13#10 +
      ' Values: array[0..1] of Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure TRec.Foo(X: Integer); begin A := X; end;'#13#10 +
      ''#13#10 +
      'function TRec.Get: Integer; begin Result := 5; end;'#13#10 +
      'function TRec.GetAt(Index: Integer): Integer; begin Result := A + Index; end;'#13#10 +
      'procedure TRec.SetAt(Index, Value: Integer); begin A := Value + Index; end;'#13#10 +
      'procedure Foo(X: Integer); begin G := X; end;'#13#10 +
      'function Get: Integer; begin Result := 100; end;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' Item.A := 3;'#13#10 +
      ' A := 100;'#13#10 +
      ' with Item do A := Values[0];'#13#10 +
      ' Writeln(Item.A, '' '', A, '' '', G, '' '', Values[0]);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := True;
    lLocal := False;
    lExpected := ' Item.A := Values[0];';
    lExpectedEdits := 1;
    lExpectedLine := 34;
    lExpectedColumn := 2;
  end;
  if aShape = 'sol-clean-strong-indexed-write' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TRec = record'#13#10 +
      '  A: Integer;'#13#10 +
      '  procedure Foo(X: Integer);'#13#10 +
      '  function Get: Integer;'#13#10 +
      '  function GetAt(Index: Integer): Integer;'#13#10 +
      '  procedure SetAt(Index, Value: Integer);'#13#10 +
      '  property Value: Integer read Get;'#13#10 +
      '  property Values[Index: Integer]: Integer read GetAt write SetAt; default;'#13#10 +
      ' end;'#13#10 +
      ''#13#10 +
      ' TA = type TRec;'#13#10 +
      ''#13#10 +
      'var'#13#10 +
      ' Item: TA;'#13#10 +
      ' A: Integer;'#13#10 +
      ' G: Integer;'#13#10 +
      ' Values: array[0..1] of Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure TRec.Foo(X: Integer); begin A := X; end;'#13#10 +
      ''#13#10 +
      'function TRec.Get: Integer; begin Result := 5; end;'#13#10 +
      'function TRec.GetAt(Index: Integer): Integer; begin Result := A + Index; end;'#13#10 +
      'procedure TRec.SetAt(Index, Value: Integer); begin A := Value + Index; end;'#13#10 +
      'procedure Foo(X: Integer); begin G := X; end;'#13#10 +
      'function Get: Integer; begin Result := 100; end;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' Item.A := 3;'#13#10 +
      ' A := 100;'#13#10 +
      ' with Item do Values[0] := 7;'#13#10 +
      ' Writeln(Item.A, '' '', A, '' '', G, '' '', Values[0]);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := True;
    lLocal := False;
    lExpected := ' Values[0] := 7;';
    lExpectedEdits := 1;
    lExpectedLine := 34;
    lExpectedColumn := 2;
  end;
  if aShape = 'sol-clean-generic-indexed-write' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TRec<T> = record'#13#10 +
      '  A: Integer;'#13#10 +
      '  procedure Foo(X: Integer);'#13#10 +
      '  function Get: Integer;'#13#10 +
      '  function GetAt(Index: Integer): Integer;'#13#10 +
      '  procedure SetAt(Index, Value: Integer);'#13#10 +
      '  property Value: Integer read Get;'#13#10 +
      '  property Values[Index: Integer]: Integer read GetAt write SetAt; default;'#13#10 +
      ' end;'#13#10 +
      ''#13#10 +
      ' TA = TRec<Integer>;'#13#10 +
      ''#13#10 +
      'var'#13#10 +
      ' Item: TA;'#13#10 +
      ' A: Integer;'#13#10 +
      ' G: Integer;'#13#10 +
      ' Values: array[0..1] of Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure TRec<T>.Foo(X: Integer); begin A := X; end;'#13#10 +
      ''#13#10 +
      'function TRec<T>.Get: Integer; begin Result := 5; end;'#13#10 +
      'function TRec<T>.GetAt(Index: Integer): Integer; begin Result := A + Index; end;'#13#10 +
      'procedure TRec<T>.SetAt(Index, Value: Integer); begin A := Value + Index; end;'#13#10 +
      'procedure Foo(X: Integer); begin G := X; end;'#13#10 +
      'function Get: Integer; begin Result := 100; end;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' Item.A := 3;'#13#10 +
      ' A := 100;'#13#10 +
      ' with Item do Values[0] := 7;'#13#10 +
      ' Writeln(Item.A, '' '', A, '' '', G, '' '', Values[0]);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := True;
    lLocal := False;
    lExpected := ' Values[0] := 7;';
    lExpectedEdits := 1;
    lExpectedLine := 34;
    lExpectedColumn := 2;
  end;
  if aShape = 'control-h1-field-array-w' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TSub = record S: Integer; end;'#13#10 +
      ' TItem = record'#13#10 +
      '  A: Integer;'#13#10 +
      '  Arr: array[0..1] of Integer;'#13#10 +
      '  Sub: TSub;'#13#10 +
      ' end;'#13#10 +
      'type'#13#10 +
      ' TX = TItem;'#13#10 +
      'var'#13#10 +
      ' Item: TX;'#13#10 +
      ' G: Integer = 0;'#13#10 +
      ' Arr: array[0..1] of Integer = (40, 41);'#13#10 +
      ' Sub: TSub;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' Item.Arr[1] := 21; Item.Sub.S := 5; Sub.S := 50;'#13#10 +
      ' with Item do G := Arr[1];'#13#10 +
      ' Writeln(G);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := False;
    lLocal := False;
    lExpected := ' G := Item.Arr[1];';
    lExpectedEdits := 1;
    lExpectedLine := 22;
    lExpectedColumn := 2;
  end;
  if aShape = 'control-h2-dotted-field-w' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TSub = record S: Integer; end;'#13#10 +
      ' TItem = record'#13#10 +
      '  A: Integer;'#13#10 +
      '  Arr: array[0..1] of Integer;'#13#10 +
      '  Sub: TSub;'#13#10 +
      ' end;'#13#10 +
      'type'#13#10 +
      ' TX = TItem;'#13#10 +
      'var'#13#10 +
      ' Item: TX;'#13#10 +
      ' G: Integer = 0;'#13#10 +
      ' Arr: array[0..1] of Integer = (40, 41);'#13#10 +
      ' Sub: TSub;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' Item.Arr[1] := 21; Item.Sub.S := 5; Sub.S := 50;'#13#10 +
      ' with Item do G := Sub.S;'#13#10 +
      ' Writeln(G);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := False;
    lLocal := False;
    lExpected := ' G := Item.Sub.S;';
    lExpectedEdits := 1;
    lExpectedLine := 22;
    lExpectedColumn := 2;
  end;
  if aShape = 'control-h3-dotted-write-w' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TSub = record S: Integer; end;'#13#10 +
      ' TItem = record'#13#10 +
      '  A: Integer;'#13#10 +
      '  Arr: array[0..1] of Integer;'#13#10 +
      '  Sub: TSub;'#13#10 +
      ' end;'#13#10 +
      'type'#13#10 +
      ' TX = TItem;'#13#10 +
      'var'#13#10 +
      ' Item: TX;'#13#10 +
      ' G: Integer = 0;'#13#10 +
      ' Arr: array[0..1] of Integer = (40, 41);'#13#10 +
      ' Sub: TSub;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' Item.Arr[1] := 21; Item.Sub.S := 5; Sub.S := 50;'#13#10 +
      ' with Item do Sub.S := 9; G := Item.Sub.S * 100 + Sub.S;'#13#10 +
      ' Writeln(G);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := False;
    lLocal := False;
    lExpected := ' Item.Sub.S := 9;';
    lExpectedEdits := 1;
    lExpectedLine := 22;
    lExpectedColumn := 2;
  end;
  if aShape = 'control-c5-indexed-default-w2' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'procedure Foo(X: Integer); overload;'#13#10 +
      'function Get: Integer;'#13#10 +
      'function P: Integer;'#13#10 +
      'const STR = ''xy'';'#13#10 +
      'type'#13#10 +
      ' TSub = record'#13#10 +
      '  S: Integer;'#13#10 +
      '  procedure Foo(X: Integer);'#13#10 +
      ' end;'#13#10 +
      ' TItem = record'#13#10 +
      '  A: Integer;'#13#10 +
      '  B: Integer;'#13#10 +
      '  Sub: TSub;'#13#10 +
      '  procedure Foo(X: Integer); overload;'#13#10 +
      '  procedure Foo(const X: string); overload;'#13#10 +
      '  function Get: Integer;'#13#10 +
      '  function GetP: Integer;'#13#10 +
      '  function GetItem(I: Integer): Integer;'#13#10 +
      '  property P: Integer read GetP;'#13#10 +
      '  property Items[I: Integer]: Integer read GetItem; default;'#13#10 +
      ' end;'#13#10 +
      ' TGen<T> = record'#13#10 +
      '  A: T;'#13#10 +
      '  B: T;'#13#10 +
      '  Sub: TSub;'#13#10 +
      '  procedure Foo(X: T); overload;'#13#10 +
      '  procedure Foo(const X: string); overload;'#13#10 +
      '  function Get: Integer;'#13#10 +
      '  function GetP: Integer;'#13#10 +
      '  function GetItem(I: Integer): Integer;'#13#10 +
      '  property P: Integer read GetP;'#13#10 +
      '  property Items[I: Integer]: Integer read GetItem; default;'#13#10 +
      ' end;'#13#10 +
      'type'#13#10 +
      ' TX = TItem;'#13#10 +
      'var'#13#10 +
      ' Item: TX;'#13#10 +
      ' A: Integer = 0;'#13#10 +
      ' B: Integer = 4;'#13#10 +
      ' G: Integer = 0;'#13#10 +
      ' Items: array[0..1] of Integer = (40, 41);'#13#10 +
      'implementation'#13#10 +
      'procedure TSub.Foo(X: Integer); begin S := X; end;'#13#10 +
      'procedure TItem.Foo(X: Integer); begin A := X; end;'#13#10 +
      'procedure TItem.Foo(const X: string); begin A := A + Length(X) + 10; end;'#13#10 +
      'function TItem.Get: Integer; begin Result := 5; end;'#13#10 +
      'function TItem.GetP: Integer; begin Result := 6; end;'#13#10 +
      'function TItem.GetItem(I: Integer): Integer; begin Result := 20 + I; end;'#13#10 +
      'procedure TGen<T>.Foo(X: T); begin A := X; end;'#13#10 +
      'procedure TGen<T>.Foo(const X: string); begin end;'#13#10 +
      'function TGen<T>.Get: Integer; begin Result := 5; end;'#13#10 +
      'function TGen<T>.GetP: Integer; begin Result := 6; end;'#13#10 +
      'function TGen<T>.GetItem(I: Integer): Integer; begin Result := 20 + I; end;'#13#10 +
      'procedure Foo(X: Integer); begin G := X; end;'#13#10 +
      'function Get: Integer; begin Result := 100; end;'#13#10 +
      'function P: Integer; begin Result := 200; end;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' Item.A := 0; Item.B := 3; Item.Sub.S := 0;'#13#10 +
      ' with Item do G := Items[1];'#13#10 +
      ' Writeln(Item.A, '' '', Item.Sub.S, '' '', G, '' '', A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := False;
    lLocal := False;
    lExpected := ' G := Item.Items[1];';
    lExpectedEdits := 1;
    lExpectedLine := 63;
    lExpectedColumn := 2;
  end;
  if aShape = 'control-c1-args-members-w2' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'procedure Foo(X: Integer); overload;'#13#10 +
      'function Get: Integer;'#13#10 +
      'function P: Integer;'#13#10 +
      'const STR = ''xy'';'#13#10 +
      'type'#13#10 +
      ' TSub = record'#13#10 +
      '  S: Integer;'#13#10 +
      '  procedure Foo(X: Integer);'#13#10 +
      ' end;'#13#10 +
      ' TItem = record'#13#10 +
      '  A: Integer;'#13#10 +
      '  B: Integer;'#13#10 +
      '  Sub: TSub;'#13#10 +
      '  procedure Foo(X: Integer); overload;'#13#10 +
      '  procedure Foo(const X: string); overload;'#13#10 +
      '  function Get: Integer;'#13#10 +
      '  function GetP: Integer;'#13#10 +
      '  function GetItem(I: Integer): Integer;'#13#10 +
      '  property P: Integer read GetP;'#13#10 +
      '  property Items[I: Integer]: Integer read GetItem; default;'#13#10 +
      ' end;'#13#10 +
      ' TGen<T> = record'#13#10 +
      '  A: T;'#13#10 +
      '  B: T;'#13#10 +
      '  Sub: TSub;'#13#10 +
      '  procedure Foo(X: T); overload;'#13#10 +
      '  procedure Foo(const X: string); overload;'#13#10 +
      '  function Get: Integer;'#13#10 +
      '  function GetP: Integer;'#13#10 +
      '  function GetItem(I: Integer): Integer;'#13#10 +
      '  property P: Integer read GetP;'#13#10 +
      '  property Items[I: Integer]: Integer read GetItem; default;'#13#10 +
      ' end;'#13#10 +
      'type'#13#10 +
      ' TX = TItem;'#13#10 +
      'var'#13#10 +
      ' Item: TX;'#13#10 +
      ' A: Integer = 0;'#13#10 +
      ' B: Integer = 4;'#13#10 +
      ' G: Integer = 0;'#13#10 +
      ' Items: array[0..1] of Integer = (40, 41);'#13#10 +
      'implementation'#13#10 +
      'procedure TSub.Foo(X: Integer); begin S := X; end;'#13#10 +
      'procedure TItem.Foo(X: Integer); begin A := X; end;'#13#10 +
      'procedure TItem.Foo(const X: string); begin A := A + Length(X) + 10; end;'#13#10 +
      'function TItem.Get: Integer; begin Result := 5; end;'#13#10 +
      'function TItem.GetP: Integer; begin Result := 6; end;'#13#10 +
      'function TItem.GetItem(I: Integer): Integer; begin Result := 20 + I; end;'#13#10 +
      'procedure TGen<T>.Foo(X: T); begin A := X; end;'#13#10 +
      'procedure TGen<T>.Foo(const X: string); begin end;'#13#10 +
      'function TGen<T>.Get: Integer; begin Result := 5; end;'#13#10 +
      'function TGen<T>.GetP: Integer; begin Result := 6; end;'#13#10 +
      'function TGen<T>.GetItem(I: Integer): Integer; begin Result := 20 + I; end;'#13#10 +
      'procedure Foo(X: Integer); begin G := X; end;'#13#10 +
      'function Get: Integer; begin Result := 100; end;'#13#10 +
      'function P: Integer; begin Result := 200; end;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' Item.A := 0; Item.B := 3; Item.Sub.S := 0;'#13#10 +
      ' with Item do Foo(B);'#13#10 +
      ' Writeln(Item.A, '' '', Item.Sub.S, '' '', G, '' '', A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := False;
    lLocal := False;
    lExpected := ' Item.Foo(Item.B);';
    lExpectedEdits := 1;
    lExpectedLine := 63;
    lExpectedColumn := 2;
  end;
  if aShape = 'control-clean-weak-overload' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TRec = record'#13#10 +
      '  A: Integer;'#13#10 +
      '  procedure Foo(X: Integer); overload;'#13#10 +
      ' procedure Foo(const X: string); overload;'#13#10 +
      '  function Get: Integer;'#13#10 +
      '  function GetAt(Index: Integer): Integer;'#13#10 +
      '  procedure SetAt(Index, Value: Integer);'#13#10 +
      '  property Value: Integer read Get;'#13#10 +
      '  property Values[Index: Integer]: Integer read GetAt write SetAt; default;'#13#10 +
      ' end;'#13#10 +
      ''#13#10 +
      ' TA = TRec;'#13#10 +
      ''#13#10 +
      'var'#13#10 +
      ' Item: TA;'#13#10 +
      ' A: Integer;'#13#10 +
      ' G: Integer;'#13#10 +
      ' Values: array[0..1] of Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure TRec.Foo(X: Integer); begin A := X; end;'#13#10 +
      'procedure TRec.Foo(const X: string); begin A := 9; end;'#13#10 +
      ''#13#10 +
      'function TRec.Get: Integer; begin Result := 5; end;'#13#10 +
      'function TRec.GetAt(Index: Integer): Integer; begin Result := A + Index; end;'#13#10 +
      'procedure TRec.SetAt(Index, Value: Integer); begin A := Value + Index; end;'#13#10 +
      'procedure Foo(X: Integer); begin G := X; end;'#13#10 +
      'function Get: Integer; begin Result := 100; end;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' Item.A := 3;'#13#10 +
      ' A := 100;'#13#10 +
      ' with Item do Foo(7);'#13#10 +
      ' Writeln(Item.A, '' '', A, '' '', G, '' '', Values[0]);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := False;
    lLocal := False;
    lExpected := ' Item.Foo(7);';
    lExpectedEdits := 1;
    lExpectedLine := 36;
    lExpectedColumn := 2;
  end;
  if aShape = 'control-clean-plain-overload' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TRec = record'#13#10 +
      '  A: Integer;'#13#10 +
      '  procedure Foo(X: Integer); overload;'#13#10 +
      ' procedure Foo(const X: string); overload;'#13#10 +
      '  function Get: Integer;'#13#10 +
      '  function GetAt(Index: Integer): Integer;'#13#10 +
      '  procedure SetAt(Index, Value: Integer);'#13#10 +
      '  property Value: Integer read Get;'#13#10 +
      '  property Values[Index: Integer]: Integer read GetAt write SetAt; default;'#13#10 +
      ' end;'#13#10 +
      ''#13#10 +
      'var'#13#10 +
      ' Item: TRec;'#13#10 +
      ' A: Integer;'#13#10 +
      ' G: Integer;'#13#10 +
      ' Values: array[0..1] of Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure TRec.Foo(X: Integer); begin A := X; end;'#13#10 +
      'procedure TRec.Foo(const X: string); begin A := 9; end;'#13#10 +
      ''#13#10 +
      'function TRec.Get: Integer; begin Result := 5; end;'#13#10 +
      'function TRec.GetAt(Index: Integer): Integer; begin Result := A + Index; end;'#13#10 +
      'procedure TRec.SetAt(Index, Value: Integer); begin A := Value + Index; end;'#13#10 +
      'procedure Foo(X: Integer); begin G := X; end;'#13#10 +
      'function Get: Integer; begin Result := 100; end;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' Item.A := 3;'#13#10 +
      ' A := 100;'#13#10 +
      ' with Item do Foo(7);'#13#10 +
      ' Writeln(Item.A, '' '', A, '' '', G, '' '', Values[0]);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := False;
    lLocal := False;
    lExpected := ' lWithRecPtr := @Item;'#13#10 +
      ' lWithRecPtr^.Foo(7);';
    lExpectedEdits := 2;
    lExpectedLine := 34;
    lExpectedColumn := 2;
  end;
  if aShape = 'control-getter-property-call-weak' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TProc = procedure(X: Integer);'#13#10 +
      ' TRec = record'#13#10 +
      '  Handler: TProc;'#13#10 +
      '  function GetProc: TProc;'#13#10 +
      '  property P: TProc read GetProc;'#13#10 +
      ' end;'#13#10 +
      ''#13#10 +
      ' TA = TRec;'#13#10 +
      ''#13#10 +
      'var'#13#10 +
      ' Item: TA;'#13#10 +
      ' Hit: Integer;'#13#10 +
      ' G: Integer;'#13#10 +
      'implementation'#13#10 +
      'function TRec.GetProc: TProc; begin Result := Handler; end;'#13#10 +
      'procedure P(X: Integer); begin G := X; end;'#13#10 +
      'procedure Target(X: Integer); begin Hit := X; end;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' Item.Handler := Target;'#13#10 +
      ' with Item do P(7);'#13#10 +
      ' Writeln(Hit, '' '', G);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := False;
    lLocal := False;
    lExpected := ' Item.P(7);';
    lExpectedEdits := 1;
    lExpectedLine := 25;
    lExpectedColumn := 2;
  end;
  if aShape = 'control-getter-property-call-plain' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TProc = procedure(X: Integer);'#13#10 +
      ' TRec = record'#13#10 +
      '  Handler: TProc;'#13#10 +
      '  function GetProc: TProc;'#13#10 +
      '  property P: TProc read GetProc;'#13#10 +
      ' end;'#13#10 +
      ''#13#10 +
      'var'#13#10 +
      ' Item: TRec;'#13#10 +
      ' Hit: Integer;'#13#10 +
      ' G: Integer;'#13#10 +
      'implementation'#13#10 +
      'function TRec.GetProc: TProc; begin Result := Handler; end;'#13#10 +
      'procedure P(X: Integer); begin G := X; end;'#13#10 +
      'procedure Target(X: Integer); begin Hit := X; end;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' Item.Handler := Target;'#13#10 +
      ' with Item do P(7);'#13#10 +
      ' Writeln(Hit, '' '', G);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := False;
    lLocal := False;
    lExpected := ' lWithRecPtr := @Item;'#13#10 +
      ' lWithRecPtr^.P(7);';
    lExpectedEdits := 2;
    lExpectedLine := 23;
    lExpectedColumn := 2;
  end;
  if aShape = 'control-clean-weak-indexed-read' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TRec = record'#13#10 +
      '  A: Integer;'#13#10 +
      '  procedure Foo(X: Integer);'#13#10 +
      '  function Get: Integer;'#13#10 +
      '  function GetAt(Index: Integer): Integer;'#13#10 +
      '  procedure SetAt(Index, Value: Integer);'#13#10 +
      '  property Value: Integer read Get;'#13#10 +
      '  property Values[Index: Integer]: Integer read GetAt write SetAt; default;'#13#10 +
      ' end;'#13#10 +
      ''#13#10 +
      ' TA = TRec;'#13#10 +
      ''#13#10 +
      'var'#13#10 +
      ' Item: TA;'#13#10 +
      ' A: Integer;'#13#10 +
      ' G: Integer;'#13#10 +
      ' Values: array[0..1] of Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure TRec.Foo(X: Integer); begin A := X; end;'#13#10 +
      ''#13#10 +
      'function TRec.Get: Integer; begin Result := 5; end;'#13#10 +
      'function TRec.GetAt(Index: Integer): Integer; begin Result := A + Index; end;'#13#10 +
      'procedure TRec.SetAt(Index, Value: Integer); begin A := Value + Index; end;'#13#10 +
      'procedure Foo(X: Integer); begin G := X; end;'#13#10 +
      'function Get: Integer; begin Result := 100; end;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' Item.A := 3;'#13#10 +
      ' A := 100;'#13#10 +
      ' with Item do A := Values[0];'#13#10 +
      ' Writeln(Item.A, '' '', A, '' '', G, '' '', Values[0]);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := False;
    lLocal := False;
    lExpected := ' Item.A := Item.Values[0];';
    lExpectedEdits := 1;
    lExpectedLine := 34;
    lExpectedColumn := 2;
  end;
  if aShape = 'control-clean-plain-indexed-read' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TRec = record'#13#10 +
      '  A: Integer;'#13#10 +
      '  procedure Foo(X: Integer);'#13#10 +
      '  function Get: Integer;'#13#10 +
      '  function GetAt(Index: Integer): Integer;'#13#10 +
      '  procedure SetAt(Index, Value: Integer);'#13#10 +
      '  property Value: Integer read Get;'#13#10 +
      '  property Values[Index: Integer]: Integer read GetAt write SetAt; default;'#13#10 +
      ' end;'#13#10 +
      ''#13#10 +
      'var'#13#10 +
      ' Item: TRec;'#13#10 +
      ' A: Integer;'#13#10 +
      ' G: Integer;'#13#10 +
      ' Values: array[0..1] of Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure TRec.Foo(X: Integer); begin A := X; end;'#13#10 +
      ''#13#10 +
      'function TRec.Get: Integer; begin Result := 5; end;'#13#10 +
      'function TRec.GetAt(Index: Integer): Integer; begin Result := A + Index; end;'#13#10 +
      'procedure TRec.SetAt(Index, Value: Integer); begin A := Value + Index; end;'#13#10 +
      'procedure Foo(X: Integer); begin G := X; end;'#13#10 +
      'function Get: Integer; begin Result := 100; end;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' Item.A := 3;'#13#10 +
      ' A := 100;'#13#10 +
      ' with Item do A := Values[0];'#13#10 +
      ' Writeln(Item.A, '' '', A, '' '', G, '' '', Values[0]);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := False;
    lLocal := False;
    lExpected := ' lWithRecPtr := @Item;'#13#10 +
      ' lWithRecPtr^.A := lWithRecPtr^.Values[0];';
    lExpectedEdits := 2;
    lExpectedLine := 32;
    lExpectedColumn := 2;
  end;
  if aShape = 'control-clean-weak-indexed-write' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TRec = record'#13#10 +
      '  A: Integer;'#13#10 +
      '  procedure Foo(X: Integer);'#13#10 +
      '  function Get: Integer;'#13#10 +
      '  function GetAt(Index: Integer): Integer;'#13#10 +
      '  procedure SetAt(Index, Value: Integer);'#13#10 +
      '  property Value: Integer read Get;'#13#10 +
      '  property Values[Index: Integer]: Integer read GetAt write SetAt; default;'#13#10 +
      ' end;'#13#10 +
      ''#13#10 +
      ' TA = TRec;'#13#10 +
      ''#13#10 +
      'var'#13#10 +
      ' Item: TA;'#13#10 +
      ' A: Integer;'#13#10 +
      ' G: Integer;'#13#10 +
      ' Values: array[0..1] of Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure TRec.Foo(X: Integer); begin A := X; end;'#13#10 +
      ''#13#10 +
      'function TRec.Get: Integer; begin Result := 5; end;'#13#10 +
      'function TRec.GetAt(Index: Integer): Integer; begin Result := A + Index; end;'#13#10 +
      'procedure TRec.SetAt(Index, Value: Integer); begin A := Value + Index; end;'#13#10 +
      'procedure Foo(X: Integer); begin G := X; end;'#13#10 +
      'function Get: Integer; begin Result := 100; end;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' Item.A := 3;'#13#10 +
      ' A := 100;'#13#10 +
      ' with Item do Values[0] := 7;'#13#10 +
      ' Writeln(Item.A, '' '', A, '' '', G, '' '', Values[0]);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := False;
    lLocal := False;
    lExpected := ' Item.Values[0] := 7;';
    lExpectedEdits := 1;
    lExpectedLine := 34;
    lExpectedColumn := 2;
  end;
  if aShape = 'control-clean-plain-indexed-write' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TRec = record'#13#10 +
      '  A: Integer;'#13#10 +
      '  procedure Foo(X: Integer);'#13#10 +
      '  function Get: Integer;'#13#10 +
      '  function GetAt(Index: Integer): Integer;'#13#10 +
      '  procedure SetAt(Index, Value: Integer);'#13#10 +
      '  property Value: Integer read Get;'#13#10 +
      '  property Values[Index: Integer]: Integer read GetAt write SetAt; default;'#13#10 +
      ' end;'#13#10 +
      ''#13#10 +
      'var'#13#10 +
      ' Item: TRec;'#13#10 +
      ' A: Integer;'#13#10 +
      ' G: Integer;'#13#10 +
      ' Values: array[0..1] of Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure TRec.Foo(X: Integer); begin A := X; end;'#13#10 +
      ''#13#10 +
      'function TRec.Get: Integer; begin Result := 5; end;'#13#10 +
      'function TRec.GetAt(Index: Integer): Integer; begin Result := A + Index; end;'#13#10 +
      'procedure TRec.SetAt(Index, Value: Integer); begin A := Value + Index; end;'#13#10 +
      'procedure Foo(X: Integer); begin G := X; end;'#13#10 +
      'function Get: Integer; begin Result := 100; end;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' Item.A := 3;'#13#10 +
      ' A := 100;'#13#10 +
      ' with Item do Values[0] := 7;'#13#10 +
      ' Writeln(Item.A, '' '', A, '' '', G, '' '', Values[0]);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := False;
    lLocal := False;
    lExpected := ' lWithRecPtr := @Item;'#13#10 +
      ' lWithRecPtr^.Values[0] := 7;';
    lExpectedEdits := 2;
    lExpectedLine := 32;
    lExpectedColumn := 2;
  end;
  if aShape = 'control-opus-e7-forward-nested-strong-weak' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TItem = record'#13#10 +
      '  A: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TOther = record'#13#10 +
      '  B: Integer;'#13#10 +
      ' end;'#13#10 +
      'var'#13#10 +
      ' A: Integer = 0;'#13#10 +
      ' B: Integer = 0;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'type TA = TItem;'#13#10 +
      'var Item: TA;'#13#10 +
      '  procedure Inner; forward;'#13#10 +
      '  procedure Other;'#13#10 +
      '  begin'#13#10 +
      '    Inner;'#13#10 +
      '  end;'#13#10 +
      '  procedure Inner;'#13#10 +
      '  begin'#13#10 +
      '    with Item do A := 7;'#13#10 +
      '  end;'#13#10 +
      'begin'#13#10 +
      '  Item.A := 0;'#13#10 +
      '  Other;'#13#10 +
      '  Writeln(Item.A, '' '', A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := False;
    lExpected := ' Item.A := 7;';
    lExpectedEdits := 1;
    lExpectedLine := 25;
    lExpectedColumn := 5;
  end;
  if aShape = 'control-opus-e7-forward-nested-strong-plain' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TItem = record'#13#10 +
      '  A: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TOther = record'#13#10 +
      '  B: Integer;'#13#10 +
      ' end;'#13#10 +
      'var'#13#10 +
      ' A: Integer = 0;'#13#10 +
      ' B: Integer = 0;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'type TA = TItem;'#13#10 +
      'var Item: TItem;'#13#10 +
      '  procedure Inner; forward;'#13#10 +
      '  procedure Other;'#13#10 +
      '  begin'#13#10 +
      '    Inner;'#13#10 +
      '  end;'#13#10 +
      '  procedure Inner;'#13#10 +
      '  begin'#13#10 +
      '    with Item do A := 7;'#13#10 +
      '  end;'#13#10 +
      'begin'#13#10 +
      '  Item.A := 0;'#13#10 +
      '  Other;'#13#10 +
      '  Writeln(Item.A, '' '', A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := False;
    lExpected := '    lWithItemPtr := @Item;'#13#10 +
      ' lWithItemPtr^.A := 7;';
    lExpectedEdits := 2;
    lExpectedLine := 25;
    lExpectedColumn := 5;
  end;
  if aShape = 'control-opus-e14-forward-two-level-strong-weak' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TItem = record'#13#10 +
      '  A: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TOther = record'#13#10 +
      '  B: Integer;'#13#10 +
      ' end;'#13#10 +
      'var'#13#10 +
      ' A: Integer = 0;'#13#10 +
      ' B: Integer = 0;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'type TA = TItem;'#13#10 +
      'var Item: TA;'#13#10 +
      '  procedure Mid; forward;'#13#10 +
      '  procedure Other;'#13#10 +
      '  begin'#13#10 +
      '    Mid;'#13#10 +
      '  end;'#13#10 +
      '  procedure Mid;'#13#10 +
      '    procedure Inner;'#13#10 +
      '    begin'#13#10 +
      '      with Item do A := 7;'#13#10 +
      '    end;'#13#10 +
      '  begin'#13#10 +
      '    Inner;'#13#10 +
      '  end;'#13#10 +
      'begin'#13#10 +
      '  Item.A := 0;'#13#10 +
      '  Other;'#13#10 +
      '  Writeln(Item.A, '' '', A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := False;
    lExpected := ' Item.A := 7;';
    lExpectedEdits := 1;
    lExpectedLine := 26;
    lExpectedColumn := 7;
  end;
  if aShape = 'control-opus-e14-forward-two-level-strong-plain' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TItem = record'#13#10 +
      '  A: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TOther = record'#13#10 +
      '  B: Integer;'#13#10 +
      ' end;'#13#10 +
      'var'#13#10 +
      ' A: Integer = 0;'#13#10 +
      ' B: Integer = 0;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'type TA = TItem;'#13#10 +
      'var Item: TItem;'#13#10 +
      '  procedure Mid; forward;'#13#10 +
      '  procedure Other;'#13#10 +
      '  begin'#13#10 +
      '    Mid;'#13#10 +
      '  end;'#13#10 +
      '  procedure Mid;'#13#10 +
      '    procedure Inner;'#13#10 +
      '    begin'#13#10 +
      '      with Item do A := 7;'#13#10 +
      '    end;'#13#10 +
      '  begin'#13#10 +
      '    Inner;'#13#10 +
      '  end;'#13#10 +
      'begin'#13#10 +
      '  Item.A := 0;'#13#10 +
      '  Other;'#13#10 +
      '  Writeln(Item.A, '' '', A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := False;
    lExpected := '      lWithItemPtr := @Item;'#13#10 +
      ' lWithItemPtr^.A := 7;';
    lExpectedEdits := 2;
    lExpectedLine := 26;
    lExpectedColumn := 7;
  end;
  if aShape = 'control-h1-field-array-w-plain' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TSub = record S: Integer; end;'#13#10 +
      ' TItem = record'#13#10 +
      '  A: Integer;'#13#10 +
      '  Arr: array[0..1] of Integer;'#13#10 +
      '  Sub: TSub;'#13#10 +
      ' end;'#13#10 +
      'type'#13#10 +
      ' TX = TItem;'#13#10 +
      'var'#13#10 +
      ' Item: TItem;'#13#10 +
      ' G: Integer = 0;'#13#10 +
      ' Arr: array[0..1] of Integer = (40, 41);'#13#10 +
      ' Sub: TSub;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' Item.Arr[1] := 21; Item.Sub.S := 5; Sub.S := 50;'#13#10 +
      ' with Item do G := Arr[1];'#13#10 +
      ' Writeln(G);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := False;
    lExpected := ' lWithItemPtr := @Item;'#13#10 +
      ' G := lWithItemPtr^.Arr[1];';
    lExpectedEdits := 2;
    lExpectedLine := 22;
    lExpectedColumn := 2;
  end;
  if aShape = 'control-h2-dotted-field-w-plain' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TSub = record S: Integer; end;'#13#10 +
      ' TItem = record'#13#10 +
      '  A: Integer;'#13#10 +
      '  Arr: array[0..1] of Integer;'#13#10 +
      '  Sub: TSub;'#13#10 +
      ' end;'#13#10 +
      'type'#13#10 +
      ' TX = TItem;'#13#10 +
      'var'#13#10 +
      ' Item: TItem;'#13#10 +
      ' G: Integer = 0;'#13#10 +
      ' Arr: array[0..1] of Integer = (40, 41);'#13#10 +
      ' Sub: TSub;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' Item.Arr[1] := 21; Item.Sub.S := 5; Sub.S := 50;'#13#10 +
      ' with Item do G := Sub.S;'#13#10 +
      ' Writeln(G);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := False;
    lExpected := ' lWithItemPtr := @Item;'#13#10 +
      ' G := lWithItemPtr^.Sub.S;';
    lExpectedEdits := 2;
    lExpectedLine := 22;
    lExpectedColumn := 2;
  end;
  if aShape = 'control-h3-dotted-write-w-plain' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TSub = record S: Integer; end;'#13#10 +
      ' TItem = record'#13#10 +
      '  A: Integer;'#13#10 +
      '  Arr: array[0..1] of Integer;'#13#10 +
      '  Sub: TSub;'#13#10 +
      ' end;'#13#10 +
      'type'#13#10 +
      ' TX = TItem;'#13#10 +
      'var'#13#10 +
      ' Item: TItem;'#13#10 +
      ' G: Integer = 0;'#13#10 +
      ' Arr: array[0..1] of Integer = (40, 41);'#13#10 +
      ' Sub: TSub;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' Item.Arr[1] := 21; Item.Sub.S := 5; Sub.S := 50;'#13#10 +
      ' with Item do Sub.S := 9; G := Item.Sub.S * 100 + Sub.S;'#13#10 +
      ' Writeln(G);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := False;
    lExpected := ' lWithItemPtr := @Item;'#13#10 +
      ' lWithItemPtr^.Sub.S := 9;';
    lExpectedEdits := 2;
    lExpectedLine := 22;
    lExpectedColumn := 2;
  end;
  if aShape = 'control-c5-indexed-default-w2-plain' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'procedure Foo(X: Integer); overload;'#13#10 +
      'function Get: Integer;'#13#10 +
      'function P: Integer;'#13#10 +
      'const STR = ''xy'';'#13#10 +
      'type'#13#10 +
      ' TSub = record'#13#10 +
      '  S: Integer;'#13#10 +
      '  procedure Foo(X: Integer);'#13#10 +
      ' end;'#13#10 +
      ' TItem = record'#13#10 +
      '  A: Integer;'#13#10 +
      '  B: Integer;'#13#10 +
      '  Sub: TSub;'#13#10 +
      '  procedure Foo(X: Integer); overload;'#13#10 +
      '  procedure Foo(const X: string); overload;'#13#10 +
      '  function Get: Integer;'#13#10 +
      '  function GetP: Integer;'#13#10 +
      '  function GetItem(I: Integer): Integer;'#13#10 +
      '  property P: Integer read GetP;'#13#10 +
      '  property Items[I: Integer]: Integer read GetItem; default;'#13#10 +
      ' end;'#13#10 +
      ' TGen<T> = record'#13#10 +
      '  A: T;'#13#10 +
      '  B: T;'#13#10 +
      '  Sub: TSub;'#13#10 +
      '  procedure Foo(X: T); overload;'#13#10 +
      '  procedure Foo(const X: string); overload;'#13#10 +
      '  function Get: Integer;'#13#10 +
      '  function GetP: Integer;'#13#10 +
      '  function GetItem(I: Integer): Integer;'#13#10 +
      '  property P: Integer read GetP;'#13#10 +
      '  property Items[I: Integer]: Integer read GetItem; default;'#13#10 +
      ' end;'#13#10 +
      'type'#13#10 +
      ' TX = TItem;'#13#10 +
      'var'#13#10 +
      ' Item: TItem;'#13#10 +
      ' A: Integer = 0;'#13#10 +
      ' B: Integer = 4;'#13#10 +
      ' G: Integer = 0;'#13#10 +
      ' Items: array[0..1] of Integer = (40, 41);'#13#10 +
      'implementation'#13#10 +
      'procedure TSub.Foo(X: Integer); begin S := X; end;'#13#10 +
      'procedure TItem.Foo(X: Integer); begin A := X; end;'#13#10 +
      'procedure TItem.Foo(const X: string); begin A := A + Length(X) + 10; end;'#13#10 +
      'function TItem.Get: Integer; begin Result := 5; end;'#13#10 +
      'function TItem.GetP: Integer; begin Result := 6; end;'#13#10 +
      'function TItem.GetItem(I: Integer): Integer; begin Result := 20 + I; end;'#13#10 +
      'procedure TGen<T>.Foo(X: T); begin A := X; end;'#13#10 +
      'procedure TGen<T>.Foo(const X: string); begin end;'#13#10 +
      'function TGen<T>.Get: Integer; begin Result := 5; end;'#13#10 +
      'function TGen<T>.GetP: Integer; begin Result := 6; end;'#13#10 +
      'function TGen<T>.GetItem(I: Integer): Integer; begin Result := 20 + I; end;'#13#10 +
      'procedure Foo(X: Integer); begin G := X; end;'#13#10 +
      'function Get: Integer; begin Result := 100; end;'#13#10 +
      'function P: Integer; begin Result := 200; end;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' Item.A := 0; Item.B := 3; Item.Sub.S := 0;'#13#10 +
      ' with Item do G := Items[1];'#13#10 +
      ' Writeln(Item.A, '' '', Item.Sub.S, '' '', G, '' '', A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := False;
    lExpected := ' lWithItemPtr := @Item;'#13#10 +
      ' G := lWithItemPtr^.Items[1];';
    lExpectedEdits := 2;
    lExpectedLine := 63;
    lExpectedColumn := 2;
  end;
  if aShape = 'control-c1-args-members-w2-plain' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'procedure Foo(X: Integer); overload;'#13#10 +
      'function Get: Integer;'#13#10 +
      'function P: Integer;'#13#10 +
      'const STR = ''xy'';'#13#10 +
      'type'#13#10 +
      ' TSub = record'#13#10 +
      '  S: Integer;'#13#10 +
      '  procedure Foo(X: Integer);'#13#10 +
      ' end;'#13#10 +
      ' TItem = record'#13#10 +
      '  A: Integer;'#13#10 +
      '  B: Integer;'#13#10 +
      '  Sub: TSub;'#13#10 +
      '  procedure Foo(X: Integer); overload;'#13#10 +
      '  procedure Foo(const X: string); overload;'#13#10 +
      '  function Get: Integer;'#13#10 +
      '  function GetP: Integer;'#13#10 +
      '  function GetItem(I: Integer): Integer;'#13#10 +
      '  property P: Integer read GetP;'#13#10 +
      '  property Items[I: Integer]: Integer read GetItem; default;'#13#10 +
      ' end;'#13#10 +
      ' TGen<T> = record'#13#10 +
      '  A: T;'#13#10 +
      '  B: T;'#13#10 +
      '  Sub: TSub;'#13#10 +
      '  procedure Foo(X: T); overload;'#13#10 +
      '  procedure Foo(const X: string); overload;'#13#10 +
      '  function Get: Integer;'#13#10 +
      '  function GetP: Integer;'#13#10 +
      '  function GetItem(I: Integer): Integer;'#13#10 +
      '  property P: Integer read GetP;'#13#10 +
      '  property Items[I: Integer]: Integer read GetItem; default;'#13#10 +
      ' end;'#13#10 +
      'type'#13#10 +
      ' TX = TItem;'#13#10 +
      'var'#13#10 +
      ' Item: TItem;'#13#10 +
      ' A: Integer = 0;'#13#10 +
      ' B: Integer = 4;'#13#10 +
      ' G: Integer = 0;'#13#10 +
      ' Items: array[0..1] of Integer = (40, 41);'#13#10 +
      'implementation'#13#10 +
      'procedure TSub.Foo(X: Integer); begin S := X; end;'#13#10 +
      'procedure TItem.Foo(X: Integer); begin A := X; end;'#13#10 +
      'procedure TItem.Foo(const X: string); begin A := A + Length(X) + 10; end;'#13#10 +
      'function TItem.Get: Integer; begin Result := 5; end;'#13#10 +
      'function TItem.GetP: Integer; begin Result := 6; end;'#13#10 +
      'function TItem.GetItem(I: Integer): Integer; begin Result := 20 + I; end;'#13#10 +
      'procedure TGen<T>.Foo(X: T); begin A := X; end;'#13#10 +
      'procedure TGen<T>.Foo(const X: string); begin end;'#13#10 +
      'function TGen<T>.Get: Integer; begin Result := 5; end;'#13#10 +
      'function TGen<T>.GetP: Integer; begin Result := 6; end;'#13#10 +
      'function TGen<T>.GetItem(I: Integer): Integer; begin Result := 20 + I; end;'#13#10 +
      'procedure Foo(X: Integer); begin G := X; end;'#13#10 +
      'function Get: Integer; begin Result := 100; end;'#13#10 +
      'function P: Integer; begin Result := 200; end;'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' Item.A := 0; Item.B := 3; Item.Sub.S := 0;'#13#10 +
      ' with Item do Foo(B);'#13#10 +
      ' Writeln(Item.A, '' '', Item.Sub.S, '' '', G, '' '', A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10 +
      '';
    lRefused := False;
    lExpected := ' lWithItemPtr := @Item;'#13#10 +
      ' lWithItemPtr^.Foo(lWithItemPtr^.B);';
    lExpectedEdits := 2;
    lExpectedLine := 63;
    lExpectedColumn := 2;
  end;
  if aShape = 'r5-inline-name' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses System.SysUtils;'#13#10 +
      'type TA = TSearchRec;'#13#10 +
      'var'#13#10 +
      ' SR: TA;'#13#10 +
      ' Name: string = ''xyz'';'#13#10 +
      ' Size: Int64 = 100;'#13#10 +
      'procedure Run;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' SR := Default(TA); SR.Name := ''abc''; SR.Size := 7;'#13#10 +
      ' with SR do Name := ''Z'';'#13#10 +
      ' Writeln(SR.Name, '' '', Name, '' '', SR.Size, '' '', Size);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    lRefused := True;
    lExpected := '';
    lExpectedEdits := 0;
    lExpectedLine := 14;
    lExpectedColumn := 2;
  end;
  if aShape = 'r5-inline-size' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses System.SysUtils;'#13#10 +
      'type TA = TSearchRec;'#13#10 +
      'var'#13#10 +
      ' SR: TA;'#13#10 +
      ' Name: string = ''xyz'';'#13#10 +
      ' Size: Int64 = 100;'#13#10 +
      'procedure Run;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' SR := Default(TA); SR.Name := ''abc''; SR.Size := 7;'#13#10 +
      ' with SR do Size := 9;'#13#10 +
      ' Writeln(SR.Name, '' '', Name, '' '', SR.Size, '' '', Size);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    lRefused := True;
    lExpected := '';
    lExpectedEdits := 0;
    lExpectedLine := 14;
    lExpectedColumn := 2;
  end;
  if aShape = 'r5-inline-indexed' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses System.SysUtils;'#13#10 +
      'type TA = TSearchRec;'#13#10 +
      'var'#13#10 +
      ' SR: TA;'#13#10 +
      ' Name: string = ''xyz'';'#13#10 +
      ' Size: Int64 = 100;'#13#10 +
      'procedure Run;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' SR := Default(TA); SR.Name := ''abc''; SR.Size := 7;'#13#10 +
      ' with SR do Name[1] := ''Z'';'#13#10 +
      ' Writeln(SR.Name, '' '', Name, '' '', SR.Size, '' '', Size);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    lRefused := True;
    lExpected := '';
    lExpectedEdits := 0;
    lExpectedLine := 14;
    lExpectedColumn := 2;
  end;
  if aShape = 'r5-multi-name' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses System.SysUtils;'#13#10 +
      'type TB = TSearchRec; TA = TB;'#13#10 +
      'var'#13#10 +
      ' SR: TA;'#13#10 +
      ' Name: string = ''xyz'';'#13#10 +
      ' Size: Int64 = 100;'#13#10 +
      'procedure Run;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' SR := Default(TA); SR.Name := ''abc''; SR.Size := 7;'#13#10 +
      ' with SR do Name := ''Z'';'#13#10 +
      ' Writeln(SR.Name, '' '', Name, '' '', SR.Size, '' '', Size);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    lRefused := True;
    lExpected := '';
    lExpectedEdits := 0;
    lExpectedLine := 14;
    lExpectedColumn := 2;
  end;
  if aShape = 'r5-multi-size' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses System.SysUtils;'#13#10 +
      'type TB = TSearchRec; TA = TB;'#13#10 +
      'var'#13#10 +
      ' SR: TA;'#13#10 +
      ' Name: string = ''xyz'';'#13#10 +
      ' Size: Int64 = 100;'#13#10 +
      'procedure Run;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' SR := Default(TA); SR.Name := ''abc''; SR.Size := 7;'#13#10 +
      ' with SR do Size := 9;'#13#10 +
      ' Writeln(SR.Name, '' '', Name, '' '', SR.Size, '' '', Size);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    lRefused := True;
    lExpected := '';
    lExpectedEdits := 0;
    lExpectedLine := 14;
    lExpectedColumn := 2;
  end;
  if aShape = 'r5-multi-indexed' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses System.SysUtils;'#13#10 +
      'type TB = TSearchRec; TA = TB;'#13#10 +
      'var'#13#10 +
      ' SR: TA;'#13#10 +
      ' Name: string = ''xyz'';'#13#10 +
      ' Size: Int64 = 100;'#13#10 +
      'procedure Run;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' SR := Default(TA); SR.Name := ''abc''; SR.Size := 7;'#13#10 +
      ' with SR do Name[1] := ''Z'';'#13#10 +
      ' Writeln(SR.Name, '' '', Name, '' '', SR.Size, '' '', Size);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    lRefused := True;
    lExpected := '';
    lExpectedEdits := 0;
    lExpectedLine := 14;
    lExpectedColumn := 2;
  end;
  if aShape = 'r5-comment-name' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses System.SysUtils;'#13#10 +
      'type { alias declaration } TA = TSearchRec;'#13#10 +
      'var'#13#10 +
      ' SR: TA;'#13#10 +
      ' Name: string = ''xyz'';'#13#10 +
      ' Size: Int64 = 100;'#13#10 +
      'procedure Run;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' SR := Default(TA); SR.Name := ''abc''; SR.Size := 7;'#13#10 +
      ' with SR do Name := ''Z'';'#13#10 +
      ' Writeln(SR.Name, '' '', Name, '' '', SR.Size, '' '', Size);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    lRefused := True;
    lExpected := '';
    lExpectedEdits := 0;
    lExpectedLine := 14;
    lExpectedColumn := 2;
  end;
  if aShape = 'r5-comment-size' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses System.SysUtils;'#13#10 +
      'type { alias declaration } TA = TSearchRec;'#13#10 +
      'var'#13#10 +
      ' SR: TA;'#13#10 +
      ' Name: string = ''xyz'';'#13#10 +
      ' Size: Int64 = 100;'#13#10 +
      'procedure Run;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' SR := Default(TA); SR.Name := ''abc''; SR.Size := 7;'#13#10 +
      ' with SR do Size := 9;'#13#10 +
      ' Writeln(SR.Name, '' '', Name, '' '', SR.Size, '' '', Size);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    lRefused := True;
    lExpected := '';
    lExpectedEdits := 0;
    lExpectedLine := 14;
    lExpectedColumn := 2;
  end;
  if aShape = 'r5-comment-indexed' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses System.SysUtils;'#13#10 +
      'type { alias declaration } TA = TSearchRec;'#13#10 +
      'var'#13#10 +
      ' SR: TA;'#13#10 +
      ' Name: string = ''xyz'';'#13#10 +
      ' Size: Int64 = 100;'#13#10 +
      'procedure Run;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' SR := Default(TA); SR.Name := ''abc''; SR.Size := 7;'#13#10 +
      ' with SR do Name[1] := ''Z'';'#13#10 +
      ' Writeln(SR.Name, '' '', Name, '' '', SR.Size, '' '', Size);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    lRefused := True;
    lExpected := '';
    lExpectedEdits := 0;
    lExpectedLine := 14;
    lExpectedColumn := 2;
  end;
  if aShape = 'r5-newline-name' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses System.SysUtils;'#13#10 +
      'type'#13#10 +
      ' TA = TSearchRec;'#13#10 +
      'var'#13#10 +
      ' SR: TA;'#13#10 +
      ' Name: string = ''xyz'';'#13#10 +
      ' Size: Int64 = 100;'#13#10 +
      'procedure Run;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' SR := Default(TA); SR.Name := ''abc''; SR.Size := 7;'#13#10 +
      ' with SR do Name := ''Z'';'#13#10 +
      ' Writeln(SR.Name, '' '', Name, '' '', SR.Size, '' '', Size);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    lRefused := False;
    lExpected := ' SR.Name := ''Z'';';
    lExpectedEdits := 1;
    lExpectedLine := 15;
    lExpectedColumn := 2;
  end;
  if aShape = 'r5-newline-size' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses System.SysUtils;'#13#10 +
      'type'#13#10 +
      ' TA = TSearchRec;'#13#10 +
      'var'#13#10 +
      ' SR: TA;'#13#10 +
      ' Name: string = ''xyz'';'#13#10 +
      ' Size: Int64 = 100;'#13#10 +
      'procedure Run;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' SR := Default(TA); SR.Name := ''abc''; SR.Size := 7;'#13#10 +
      ' with SR do Size := 9;'#13#10 +
      ' Writeln(SR.Name, '' '', Name, '' '', SR.Size, '' '', Size);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    lRefused := False;
    lExpected := ' SR.Size := 9;';
    lExpectedEdits := 1;
    lExpectedLine := 15;
    lExpectedColumn := 2;
  end;
  if aShape = 'r5-newline-indexed' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses System.SysUtils;'#13#10 +
      'type'#13#10 +
      ' TA = TSearchRec;'#13#10 +
      'var'#13#10 +
      ' SR: TA;'#13#10 +
      ' Name: string = ''xyz'';'#13#10 +
      ' Size: Int64 = 100;'#13#10 +
      'procedure Run;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' SR := Default(TA); SR.Name := ''abc''; SR.Size := 7;'#13#10 +
      ' with SR do Name[1] := ''Z'';'#13#10 +
      ' Writeln(SR.Name, '' '', Name, '' '', SR.Size, '' '', Size);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    lRefused := False;
    lExpected := ' SR.Name[1] := ''Z'';';
    lExpectedEdits := 1;
    lExpectedLine := 15;
    lExpectedColumn := 2;
  end;
  if aShape = 'r5-chain-first-name' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses System.SysUtils;'#13#10 +
      'type TB = TSearchRec;'#13#10 +
      ' TA = TB;'#13#10 +
      'var'#13#10 +
      ' SR: TA;'#13#10 +
      ' Name: string = ''xyz'';'#13#10 +
      ' Size: Int64 = 100;'#13#10 +
      'procedure Run;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' SR := Default(TA); SR.Name := ''abc''; SR.Size := 7;'#13#10 +
      ' with SR do Name := ''Z'';'#13#10 +
      ' Writeln(SR.Name, '' '', Name, '' '', SR.Size, '' '', Size);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    lRefused := True;
    lExpected := '';
    lExpectedEdits := 0;
    lExpectedLine := 15;
    lExpectedColumn := 2;
  end;
  if aShape = 'r5-chain-first-size' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses System.SysUtils;'#13#10 +
      'type TB = TSearchRec;'#13#10 +
      ' TA = TB;'#13#10 +
      'var'#13#10 +
      ' SR: TA;'#13#10 +
      ' Name: string = ''xyz'';'#13#10 +
      ' Size: Int64 = 100;'#13#10 +
      'procedure Run;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' SR := Default(TA); SR.Name := ''abc''; SR.Size := 7;'#13#10 +
      ' with SR do Size := 9;'#13#10 +
      ' Writeln(SR.Name, '' '', Name, '' '', SR.Size, '' '', Size);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    lRefused := True;
    lExpected := '';
    lExpectedEdits := 0;
    lExpectedLine := 15;
    lExpectedColumn := 2;
  end;
  if aShape = 'r5-chain-first-indexed' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses System.SysUtils;'#13#10 +
      'type TB = TSearchRec;'#13#10 +
      ' TA = TB;'#13#10 +
      'var'#13#10 +
      ' SR: TA;'#13#10 +
      ' Name: string = ''xyz'';'#13#10 +
      ' Size: Int64 = 100;'#13#10 +
      'procedure Run;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' SR := Default(TA); SR.Name := ''abc''; SR.Size := 7;'#13#10 +
      ' with SR do Name[1] := ''Z'';'#13#10 +
      ' Writeln(SR.Name, '' '', Name, '' '', SR.Size, '' '', Size);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    lRefused := True;
    lExpected := '';
    lExpectedEdits := 0;
    lExpectedLine := 15;
    lExpectedColumn := 2;
  end;
  if aShape = 'r5-chain-second-name' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses System.SysUtils;'#13#10 +
      'type'#13#10 +
      ' TB = TSearchRec; TA = TB;'#13#10 +
      'var'#13#10 +
      ' SR: TA;'#13#10 +
      ' Name: string = ''xyz'';'#13#10 +
      ' Size: Int64 = 100;'#13#10 +
      'procedure Run;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' SR := Default(TA); SR.Name := ''abc''; SR.Size := 7;'#13#10 +
      ' with SR do Name := ''Z'';'#13#10 +
      ' Writeln(SR.Name, '' '', Name, '' '', SR.Size, '' '', Size);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    lRefused := True;
    lExpected := '';
    lExpectedEdits := 0;
    lExpectedLine := 15;
    lExpectedColumn := 2;
  end;
  if aShape = 'r5-chain-second-size' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses System.SysUtils;'#13#10 +
      'type'#13#10 +
      ' TB = TSearchRec; TA = TB;'#13#10 +
      'var'#13#10 +
      ' SR: TA;'#13#10 +
      ' Name: string = ''xyz'';'#13#10 +
      ' Size: Int64 = 100;'#13#10 +
      'procedure Run;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' SR := Default(TA); SR.Name := ''abc''; SR.Size := 7;'#13#10 +
      ' with SR do Size := 9;'#13#10 +
      ' Writeln(SR.Name, '' '', Name, '' '', SR.Size, '' '', Size);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    lRefused := True;
    lExpected := '';
    lExpectedEdits := 0;
    lExpectedLine := 15;
    lExpectedColumn := 2;
  end;
  if aShape = 'r5-chain-second-indexed' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses System.SysUtils;'#13#10 +
      'type'#13#10 +
      ' TB = TSearchRec; TA = TB;'#13#10 +
      'var'#13#10 +
      ' SR: TA;'#13#10 +
      ' Name: string = ''xyz'';'#13#10 +
      ' Size: Int64 = 100;'#13#10 +
      'procedure Run;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' SR := Default(TA); SR.Name := ''abc''; SR.Size := 7;'#13#10 +
      ' with SR do Name[1] := ''Z'';'#13#10 +
      ' Writeln(SR.Name, '' '', Name, '' '', SR.Size, '' '', Size);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    lRefused := True;
    lExpected := '';
    lExpectedEdits := 0;
    lExpectedLine := 15;
    lExpectedColumn := 2;
  end;
  if aShape = 'r5-nested-block' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses System.SysUtils;'#13#10 +
      'type'#13#10 +
      ' TA = type TSearchRec;'#13#10 +
      ' TOther = record Z: Integer; end;'#13#10 +
      'var'#13#10 +
      ' SR: TA;'#13#10 +
      ' O: TOther;'#13#10 +
      ' Name: string = ''g'';'#13#10 +
      'procedure Run;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' SR := Default(TA); SR.Name := ''abc''; O.Z := 0;'#13#10 +
      ' with SR do'#13#10 +
      ' begin'#13#10 +
      '  with O do'#13#10 +
      '  begin'#13#10 +
      '   Name := ''x''; Z := 1;'#13#10 +
      '  end;'#13#10 +
      ' end;'#13#10 +
      ' Writeln(SR.Name, '' '', Name);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    lRefused := True;
    lExpected := '';
    lExpectedEdits := 1;
    lExpectedLine := 16;
    lExpectedColumn := 2;
  end;
  if aShape = 'r5-nested-single' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses System.SysUtils;'#13#10 +
      'type'#13#10 +
      ' TA = type TSearchRec;'#13#10 +
      ' TOther = record Z: Integer; end;'#13#10 +
      'var'#13#10 +
      ' SR: TA;'#13#10 +
      ' O: TOther;'#13#10 +
      ' Name: string = ''g'';'#13#10 +
      'procedure Run;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' SR := Default(TA); SR.Name := ''abc''; O.Z := 0;'#13#10 +
      ' with SR do with O do Name := ''x'';'#13#10 +
      ' Writeln(SR.Name, '' '', Name);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    lRefused := True;
    lExpected := '';
    lExpectedEdits := 1;
    lExpectedLine := 16;
    lExpectedColumn := 2;
  end;
  if aShape = 'r5-nested-weak-strong' then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses System.SysUtils;'#13#10 +
      'type'#13#10 +
      ' TS = type TSearchRec;'#13#10 +
      ' TA = TS;'#13#10 +
      ' TOther = record Z: Integer; end;'#13#10 +
      'var'#13#10 +
      ' SR: TA;'#13#10 +
      ' O: TOther;'#13#10 +
      ' Name: string = ''g'';'#13#10 +
      'procedure Run;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' SR := Default(TA); SR.Name := ''abc''; O.Z := 0;'#13#10 +
      ' with SR do with O do Name := ''x'';'#13#10 +
      ' Writeln(SR.Name, '' '', Name);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    lRefused := True;
    lExpected := '';
    lExpectedEdits := 1;
    lExpectedLine := 17;
    lExpectedColumn := 2;
  end;
  if MatchText(aShape, ['r5-nested-repeat', 'r5-nested-different', 'r5-nested-function']) then
  begin
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses System.SysUtils;'#13#10 +
      'type'#13#10 +
      ' TA = type TSearchRec;'#13#10 +
      ' TOther = record Z: Integer; end;'#13#10 +
      'var'#13#10 +
      ' SR: TA;'#13#10 +
      ' O: TOther;'#13#10 +
      ' Name: string = ''g'';'#13#10 +
      'procedure Run;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' SR := Default(TA); SR.Name := ''abc''; O.Z := 0;'#13#10 +
      ' with SR do with SR do Name := ''x'';'#13#10 +
      ' Writeln(SR.Name, '' '', Name);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
    lRefused := True;
    lExpected := '';
    lExpectedEdits := 1;
    lExpectedLine := 16;
    lExpectedColumn := 2;
  end;
  if aShape = 'r6-strong' then
  begin
    lSource :=
    'unit Unit1;'#13#10 +
'interface'#13#10 +
'uses System.SysUtils;'#13#10 +
'type'#13#10 +
' TR = record'#13#10 +
'   procedure Foo; overload;'#13#10 +
'   procedure Foo(X: Integer); overload;'#13#10 +
' end;'#13#10 +
' TMySR = type TR;'#13#10 +
'var'#13#10 +
' G: Integer = 0;'#13#10 +
' Name: string = ''g'';'#13#10 +
'procedure Foo;'#13#10 +
'procedure Run;'#13#10 +
'implementation'#13#10 +
'procedure Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''global'');'#13#10 +
'end;'#13#10 +
'procedure TR.Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''member'');'#13#10 +
'end;'#13#10 +
'procedure TR.Foo(X: Integer);'#13#10 +
'begin'#13#10 +
'  Writeln(''member'', X);'#13#10 +
'end;'#13#10 +
'procedure Run;'#13#10 +
'var SR: TMySR;'#13#10 +
'begin'#13#10 +
'  SR := Default(TMySR);'#13#10 +
'  with SR do'#13#10 +
'    Foo;'#13#10 +
'  Writeln(''end'');'#13#10 +
'end;'#13#10 +
'end.'#13#10;
    lRefused := True;
    lExpected := '';
    lExpectedEdits := 0;
    lExpectedLine := 32;
    lExpectedColumn := 3;
  end;
  if aShape = 'r6-control-plain-strong' then
  begin
    lSource :=
    'unit Unit1;'#13#10 +
'interface'#13#10 +
'uses System.SysUtils;'#13#10 +
'type'#13#10 +
' TR = record'#13#10 +
'   procedure Foo; overload;'#13#10 +
'   procedure Foo(X: Integer); overload;'#13#10 +
' end;'#13#10 +
' TMySR = TR;'#13#10 +
'var'#13#10 +
' G: Integer = 0;'#13#10 +
' Name: string = ''g'';'#13#10 +
'procedure Foo;'#13#10 +
'procedure Run;'#13#10 +
'implementation'#13#10 +
'procedure Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''global'');'#13#10 +
'end;'#13#10 +
'procedure TR.Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''member'');'#13#10 +
'end;'#13#10 +
'procedure TR.Foo(X: Integer);'#13#10 +
'begin'#13#10 +
'  Writeln(''member'', X);'#13#10 +
'end;'#13#10 +
'procedure Run;'#13#10 +
'var SR: TR;'#13#10 +
'begin'#13#10 +
'  SR := Default(TR);'#13#10 +
'  with SR do'#13#10 +
'    Foo;'#13#10 +
'  Writeln(''end'');'#13#10 +
'end;'#13#10 +
'end.'#13#10;
    lRefused := False;
    lExpected := '  lWithRPtr := @SR;'#13#10 +
'  lWithRPtr^.Foo;';
    lExpectedEdits := 2;
    lExpectedLine := 32;
    lExpectedColumn := 3;
  end;
  if aShape = 'r6-control-weak-strong' then
  begin
    lSource :=
    'unit Unit1;'#13#10 +
'interface'#13#10 +
'uses System.SysUtils;'#13#10 +
'type'#13#10 +
' TR = record'#13#10 +
'   procedure Foo; overload;'#13#10 +
'   procedure Foo(X: Integer); overload;'#13#10 +
' end;'#13#10 +
' TMySR = TR;'#13#10 +
'var'#13#10 +
' G: Integer = 0;'#13#10 +
' Name: string = ''g'';'#13#10 +
'procedure Foo;'#13#10 +
'procedure Run;'#13#10 +
'implementation'#13#10 +
'procedure Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''global'');'#13#10 +
'end;'#13#10 +
'procedure TR.Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''member'');'#13#10 +
'end;'#13#10 +
'procedure TR.Foo(X: Integer);'#13#10 +
'begin'#13#10 +
'  Writeln(''member'', X);'#13#10 +
'end;'#13#10 +
'procedure Run;'#13#10 +
'var SR: TMySR;'#13#10 +
'begin'#13#10 +
'  SR := Default(TMySR);'#13#10 +
'  with SR do'#13#10 +
'    Foo;'#13#10 +
'  Writeln(''end'');'#13#10 +
'end;'#13#10 +
'end.'#13#10;
    lRefused := False;
    lExpected := '  SR.Foo;';
    lExpectedEdits := 1;
    lExpectedLine := 32;
    lExpectedColumn := 3;
  end;
  if aShape = 'r6-function' then
  begin
    lSource :=
    'unit Unit1;'#13#10 +
'interface'#13#10 +
'uses System.SysUtils;'#13#10 +
'type'#13#10 +
' TR = record'#13#10 +
'   procedure Foo; overload;'#13#10 +
'   procedure Foo(X: Integer); overload;'#13#10 +
'   function Fn: Integer; overload;'#13#10 +
'   function Fn(X: Integer): Integer; overload;'#13#10 +
' end;'#13#10 +
' TOther = record Z: Integer; end;'#13#10 +
' TMySR = type TR;'#13#10 +
'var'#13#10 +
' G: Integer = 0;'#13#10 +
' Name: string = ''g'';'#13#10 +
'procedure Foo;'#13#10 +
'function Fn: Integer;'#13#10 +
'procedure Run;'#13#10 +
'implementation'#13#10 +
'procedure Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''global'');'#13#10 +
'end;'#13#10 +
'function Fn: Integer;'#13#10 +
'begin'#13#10 +
'  Result := 9;'#13#10 +
'end;'#13#10 +
'procedure TR.Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''member'');'#13#10 +
'end;'#13#10 +
'procedure TR.Foo(X: Integer);'#13#10 +
'begin'#13#10 +
'end;'#13#10 +
'function TR.Fn: Integer;'#13#10 +
'begin'#13#10 +
'  Result := 4;'#13#10 +
'end;'#13#10 +
'function TR.Fn(X: Integer): Integer;'#13#10 +
'begin'#13#10 +
'  Result := X;'#13#10 +
'end;'#13#10 +
'procedure Run;'#13#10 +
'var SR: TMySR;'#13#10 +
'begin'#13#10 +
'  SR := Default(TMySR);'#13#10 +
'  with SR do'#13#10 +
'    G := Fn;'#13#10 +
'  Writeln(G);'#13#10 +
'end;'#13#10 +
'end.'#13#10;
    lRefused := True;
    lExpected := '';
    lExpectedEdits := 0;
    lExpectedLine := 47;
    lExpectedColumn := 3;
  end;
  if aShape = 'r6-control-plain-function' then
  begin
    lSource :=
    'unit Unit1;'#13#10 +
'interface'#13#10 +
'uses System.SysUtils;'#13#10 +
'type'#13#10 +
' TR = record'#13#10 +
'   procedure Foo; overload;'#13#10 +
'   procedure Foo(X: Integer); overload;'#13#10 +
'   function Fn: Integer; overload;'#13#10 +
'   function Fn(X: Integer): Integer; overload;'#13#10 +
' end;'#13#10 +
' TOther = record Z: Integer; end;'#13#10 +
' TMySR = TR;'#13#10 +
'var'#13#10 +
' G: Integer = 0;'#13#10 +
' Name: string = ''g'';'#13#10 +
'procedure Foo;'#13#10 +
'function Fn: Integer;'#13#10 +
'procedure Run;'#13#10 +
'implementation'#13#10 +
'procedure Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''global'');'#13#10 +
'end;'#13#10 +
'function Fn: Integer;'#13#10 +
'begin'#13#10 +
'  Result := 9;'#13#10 +
'end;'#13#10 +
'procedure TR.Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''member'');'#13#10 +
'end;'#13#10 +
'procedure TR.Foo(X: Integer);'#13#10 +
'begin'#13#10 +
'end;'#13#10 +
'function TR.Fn: Integer;'#13#10 +
'begin'#13#10 +
'  Result := 4;'#13#10 +
'end;'#13#10 +
'function TR.Fn(X: Integer): Integer;'#13#10 +
'begin'#13#10 +
'  Result := X;'#13#10 +
'end;'#13#10 +
'procedure Run;'#13#10 +
'var SR: TR;'#13#10 +
'begin'#13#10 +
'  SR := Default(TR);'#13#10 +
'  with SR do'#13#10 +
'    G := Fn;'#13#10 +
'  Writeln(G);'#13#10 +
'end;'#13#10 +
'end.'#13#10;
    lRefused := False;
    lExpected := '  lWithRPtr := @SR;'#13#10 +
'  G := lWithRPtr^.Fn;';
    lExpectedEdits := 2;
    lExpectedLine := 47;
    lExpectedColumn := 3;
  end;
  if aShape = 'r6-control-weak-function' then
  begin
    lSource :=
    'unit Unit1;'#13#10 +
'interface'#13#10 +
'uses System.SysUtils;'#13#10 +
'type'#13#10 +
' TR = record'#13#10 +
'   procedure Foo; overload;'#13#10 +
'   procedure Foo(X: Integer); overload;'#13#10 +
'   function Fn: Integer; overload;'#13#10 +
'   function Fn(X: Integer): Integer; overload;'#13#10 +
' end;'#13#10 +
' TOther = record Z: Integer; end;'#13#10 +
' TMySR = TR;'#13#10 +
'var'#13#10 +
' G: Integer = 0;'#13#10 +
' Name: string = ''g'';'#13#10 +
'procedure Foo;'#13#10 +
'function Fn: Integer;'#13#10 +
'procedure Run;'#13#10 +
'implementation'#13#10 +
'procedure Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''global'');'#13#10 +
'end;'#13#10 +
'function Fn: Integer;'#13#10 +
'begin'#13#10 +
'  Result := 9;'#13#10 +
'end;'#13#10 +
'procedure TR.Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''member'');'#13#10 +
'end;'#13#10 +
'procedure TR.Foo(X: Integer);'#13#10 +
'begin'#13#10 +
'end;'#13#10 +
'function TR.Fn: Integer;'#13#10 +
'begin'#13#10 +
'  Result := 4;'#13#10 +
'end;'#13#10 +
'function TR.Fn(X: Integer): Integer;'#13#10 +
'begin'#13#10 +
'  Result := X;'#13#10 +
'end;'#13#10 +
'procedure Run;'#13#10 +
'var SR: TMySR;'#13#10 +
'begin'#13#10 +
'  SR := Default(TMySR);'#13#10 +
'  with SR do'#13#10 +
'    G := Fn;'#13#10 +
'  Writeln(G);'#13#10 +
'end;'#13#10 +
'end.'#13#10;
    lRefused := False;
    lExpected := '  G := SR.Fn;';
    lExpectedEdits := 1;
    lExpectedLine := 47;
    lExpectedColumn := 3;
  end;
  if aShape = 'r6-nested' then
  begin
    lSource :=
    'unit Unit1;'#13#10 +
'interface'#13#10 +
'uses System.SysUtils;'#13#10 +
'type'#13#10 +
' TR = record'#13#10 +
'   procedure Foo; overload;'#13#10 +
'   procedure Foo(X: Integer); overload;'#13#10 +
'   function Fn: Integer; overload;'#13#10 +
'   function Fn(X: Integer): Integer; overload;'#13#10 +
' end;'#13#10 +
' TOther = record Z: Integer; end;'#13#10 +
' TMySR = type TR;'#13#10 +
'var'#13#10 +
' G: Integer = 0;'#13#10 +
' Name: string = ''g'';'#13#10 +
'procedure Foo;'#13#10 +
'function Fn: Integer;'#13#10 +
'procedure Run;'#13#10 +
'implementation'#13#10 +
'procedure Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''global'');'#13#10 +
'end;'#13#10 +
'function Fn: Integer;'#13#10 +
'begin'#13#10 +
'  Result := 9;'#13#10 +
'end;'#13#10 +
'procedure TR.Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''member'');'#13#10 +
'end;'#13#10 +
'procedure TR.Foo(X: Integer);'#13#10 +
'begin'#13#10 +
'end;'#13#10 +
'function TR.Fn: Integer;'#13#10 +
'begin'#13#10 +
'  Result := 4;'#13#10 +
'end;'#13#10 +
'function TR.Fn(X: Integer): Integer;'#13#10 +
'begin'#13#10 +
'  Result := X;'#13#10 +
'end;'#13#10 +
'procedure Run;'#13#10 +
'var SR: TMySR; O: TOther;'#13#10 +
'begin'#13#10 +
'  SR := Default(TMySR);'#13#10 +
'  with SR do'#13#10 +
'    with O do'#13#10 +
'    begin'#13#10 +
'      Z := 1;'#13#10 +
'      Foo;'#13#10 +
'    end;'#13#10 +
'  Writeln(G);'#13#10 +
'end;'#13#10 +
'end.'#13#10;
    lRefused := True;
    lExpected := '';
    lExpectedEdits := 0;
    lExpectedLine := 47;
    lExpectedColumn := 3;
  end;
  if aShape = 'r6-control-plain-nested' then
  begin
    lSource :=
    'unit Unit1;'#13#10 +
'interface'#13#10 +
'uses System.SysUtils;'#13#10 +
'type'#13#10 +
' TR = record'#13#10 +
'   procedure Foo; overload;'#13#10 +
'   procedure Foo(X: Integer); overload;'#13#10 +
'   function Fn: Integer; overload;'#13#10 +
'   function Fn(X: Integer): Integer; overload;'#13#10 +
' end;'#13#10 +
' TOther = record Z: Integer; end;'#13#10 +
' TMySR = TR;'#13#10 +
'var'#13#10 +
' G: Integer = 0;'#13#10 +
' Name: string = ''g'';'#13#10 +
'procedure Foo;'#13#10 +
'function Fn: Integer;'#13#10 +
'procedure Run;'#13#10 +
'implementation'#13#10 +
'procedure Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''global'');'#13#10 +
'end;'#13#10 +
'function Fn: Integer;'#13#10 +
'begin'#13#10 +
'  Result := 9;'#13#10 +
'end;'#13#10 +
'procedure TR.Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''member'');'#13#10 +
'end;'#13#10 +
'procedure TR.Foo(X: Integer);'#13#10 +
'begin'#13#10 +
'end;'#13#10 +
'function TR.Fn: Integer;'#13#10 +
'begin'#13#10 +
'  Result := 4;'#13#10 +
'end;'#13#10 +
'function TR.Fn(X: Integer): Integer;'#13#10 +
'begin'#13#10 +
'  Result := X;'#13#10 +
'end;'#13#10 +
'procedure Run;'#13#10 +
'var SR: TR; O: TOther;'#13#10 +
'begin'#13#10 +
'  SR := Default(TR);'#13#10 +
'  with SR do'#13#10 +
'    with O do'#13#10 +
'    begin'#13#10 +
'      Z := 1;'#13#10 +
'      Foo;'#13#10 +
'    end;'#13#10 +
'  Writeln(G);'#13#10 +
'end;'#13#10 +
'end.'#13#10;
    lRefused := False;
    lExpected := '  lWithRPtr := @SR;'#13#10 +
'      begin'#13#10 +
'      lWithOtherPtr := @O;'#13#10 +
'      begin'#13#10 +
'      lWithOtherPtr^.Z := 1;'#13#10 +
'      lWithRPtr^.Foo;'#13#10 +
'    end;'#13#10 +
'    end;';
    lExpectedEdits := 2;
    lExpectedLine := 47;
    lExpectedColumn := 3;
  end;
  if aShape = 'r6-control-weak-nested' then
  begin
    lSource :=
    'unit Unit1;'#13#10 +
'interface'#13#10 +
'uses System.SysUtils;'#13#10 +
'type'#13#10 +
' TR = record'#13#10 +
'   procedure Foo; overload;'#13#10 +
'   procedure Foo(X: Integer); overload;'#13#10 +
'   function Fn: Integer; overload;'#13#10 +
'   function Fn(X: Integer): Integer; overload;'#13#10 +
' end;'#13#10 +
' TOther = record Z: Integer; end;'#13#10 +
' TMySR = TR;'#13#10 +
'var'#13#10 +
' G: Integer = 0;'#13#10 +
' Name: string = ''g'';'#13#10 +
'procedure Foo;'#13#10 +
'function Fn: Integer;'#13#10 +
'procedure Run;'#13#10 +
'implementation'#13#10 +
'procedure Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''global'');'#13#10 +
'end;'#13#10 +
'function Fn: Integer;'#13#10 +
'begin'#13#10 +
'  Result := 9;'#13#10 +
'end;'#13#10 +
'procedure TR.Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''member'');'#13#10 +
'end;'#13#10 +
'procedure TR.Foo(X: Integer);'#13#10 +
'begin'#13#10 +
'end;'#13#10 +
'function TR.Fn: Integer;'#13#10 +
'begin'#13#10 +
'  Result := 4;'#13#10 +
'end;'#13#10 +
'function TR.Fn(X: Integer): Integer;'#13#10 +
'begin'#13#10 +
'  Result := X;'#13#10 +
'end;'#13#10 +
'procedure Run;'#13#10 +
'var SR: TMySR; O: TOther;'#13#10 +
'begin'#13#10 +
'  SR := Default(TMySR);'#13#10 +
'  with SR do'#13#10 +
'    with O do'#13#10 +
'    begin'#13#10 +
'      Z := 1;'#13#10 +
'      Foo;'#13#10 +
'    end;'#13#10 +
'  Writeln(G);'#13#10 +
'end;'#13#10 +
'end.'#13#10;
    lRefused := False;
    lExpected := '      begin'#13#10 +
'      lWithOtherPtr := @O;'#13#10 +
'      begin'#13#10 +
'      lWithOtherPtr^.Z := 1;'#13#10 +
'      SR.Foo;'#13#10 +
'    end;'#13#10 +
'    end;';
    lExpectedEdits := 2;
    lExpectedLine := 47;
    lExpectedColumn := 3;
  end;
  if aShape = 'r6-weak-strong' then
  begin
    lSource :=
    'unit Unit1;'#13#10 +
'interface'#13#10 +
'uses System.SysUtils;'#13#10 +
'type'#13#10 +
' TR = record'#13#10 +
'   procedure Foo; overload;'#13#10 +
'   procedure Foo(X: Integer); overload;'#13#10 +
'   function Fn: Integer; overload;'#13#10 +
'   function Fn(X: Integer): Integer; overload;'#13#10 +
' end;'#13#10 +
' TOther = record Z: Integer; end;'#13#10 +
' TS = type TR;'#13#10 +
' TMySR = TS;'#13#10 +
'var'#13#10 +
' G: Integer = 0;'#13#10 +
' Name: string = ''g'';'#13#10 +
'procedure Foo;'#13#10 +
'function Fn: Integer;'#13#10 +
'procedure Run;'#13#10 +
'implementation'#13#10 +
'procedure Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''global'');'#13#10 +
'end;'#13#10 +
'function Fn: Integer;'#13#10 +
'begin'#13#10 +
'  Result := 9;'#13#10 +
'end;'#13#10 +
'procedure TR.Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''member'');'#13#10 +
'end;'#13#10 +
'procedure TR.Foo(X: Integer);'#13#10 +
'begin'#13#10 +
'end;'#13#10 +
'function TR.Fn: Integer;'#13#10 +
'begin'#13#10 +
'  Result := 4;'#13#10 +
'end;'#13#10 +
'function TR.Fn(X: Integer): Integer;'#13#10 +
'begin'#13#10 +
'  Result := X;'#13#10 +
'end;'#13#10 +
'procedure Run;'#13#10 +
'var SR: TMySR;'#13#10 +
'begin'#13#10 +
'  SR := Default(TMySR);'#13#10 +
'  with SR do'#13#10 +
'    Foo;'#13#10 +
'  Writeln(G);'#13#10 +
'end;'#13#10 +
'end.'#13#10;
    lRefused := True;
    lExpected := '';
    lExpectedEdits := 0;
    lExpectedLine := 48;
    lExpectedColumn := 3;
  end;
  if aShape = 'r6-control-plain-weak-strong' then
  begin
    lSource :=
    'unit Unit1;'#13#10 +
'interface'#13#10 +
'uses System.SysUtils;'#13#10 +
'type'#13#10 +
' TR = record'#13#10 +
'   procedure Foo; overload;'#13#10 +
'   procedure Foo(X: Integer); overload;'#13#10 +
'   function Fn: Integer; overload;'#13#10 +
'   function Fn(X: Integer): Integer; overload;'#13#10 +
' end;'#13#10 +
' TOther = record Z: Integer; end;'#13#10 +
' TS = TR;'#13#10 +
' TMySR = TS;'#13#10 +
'var'#13#10 +
' G: Integer = 0;'#13#10 +
' Name: string = ''g'';'#13#10 +
'procedure Foo;'#13#10 +
'function Fn: Integer;'#13#10 +
'procedure Run;'#13#10 +
'implementation'#13#10 +
'procedure Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''global'');'#13#10 +
'end;'#13#10 +
'function Fn: Integer;'#13#10 +
'begin'#13#10 +
'  Result := 9;'#13#10 +
'end;'#13#10 +
'procedure TR.Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''member'');'#13#10 +
'end;'#13#10 +
'procedure TR.Foo(X: Integer);'#13#10 +
'begin'#13#10 +
'end;'#13#10 +
'function TR.Fn: Integer;'#13#10 +
'begin'#13#10 +
'  Result := 4;'#13#10 +
'end;'#13#10 +
'function TR.Fn(X: Integer): Integer;'#13#10 +
'begin'#13#10 +
'  Result := X;'#13#10 +
'end;'#13#10 +
'procedure Run;'#13#10 +
'var SR: TR;'#13#10 +
'begin'#13#10 +
'  SR := Default(TR);'#13#10 +
'  with SR do'#13#10 +
'    Foo;'#13#10 +
'  Writeln(G);'#13#10 +
'end;'#13#10 +
'end.'#13#10;
    lRefused := False;
    lExpected := '  lWithRPtr := @SR;'#13#10 +
'  lWithRPtr^.Foo;';
    lExpectedEdits := 2;
    lExpectedLine := 48;
    lExpectedColumn := 3;
  end;
  if aShape = 'r6-control-weak-weak-strong' then
  begin
    lSource :=
    'unit Unit1;'#13#10 +
'interface'#13#10 +
'uses System.SysUtils;'#13#10 +
'type'#13#10 +
' TR = record'#13#10 +
'   procedure Foo; overload;'#13#10 +
'   procedure Foo(X: Integer); overload;'#13#10 +
'   function Fn: Integer; overload;'#13#10 +
'   function Fn(X: Integer): Integer; overload;'#13#10 +
' end;'#13#10 +
' TOther = record Z: Integer; end;'#13#10 +
' TS = TR;'#13#10 +
' TMySR = TS;'#13#10 +
'var'#13#10 +
' G: Integer = 0;'#13#10 +
' Name: string = ''g'';'#13#10 +
'procedure Foo;'#13#10 +
'function Fn: Integer;'#13#10 +
'procedure Run;'#13#10 +
'implementation'#13#10 +
'procedure Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''global'');'#13#10 +
'end;'#13#10 +
'function Fn: Integer;'#13#10 +
'begin'#13#10 +
'  Result := 9;'#13#10 +
'end;'#13#10 +
'procedure TR.Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''member'');'#13#10 +
'end;'#13#10 +
'procedure TR.Foo(X: Integer);'#13#10 +
'begin'#13#10 +
'end;'#13#10 +
'function TR.Fn: Integer;'#13#10 +
'begin'#13#10 +
'  Result := 4;'#13#10 +
'end;'#13#10 +
'function TR.Fn(X: Integer): Integer;'#13#10 +
'begin'#13#10 +
'  Result := X;'#13#10 +
'end;'#13#10 +
'procedure Run;'#13#10 +
'var SR: TMySR;'#13#10 +
'begin'#13#10 +
'  SR := Default(TMySR);'#13#10 +
'  with SR do'#13#10 +
'    Foo;'#13#10 +
'  Writeln(G);'#13#10 +
'end;'#13#10 +
'end.'#13#10;
    lRefused := False;
    lExpected := '  SR.Foo;';
    lExpectedEdits := 1;
    lExpectedLine := 48;
    lExpectedColumn := 3;
  end;
  if aShape = 'r6-other-unit' then
  begin
    lSource :=
    'unit Unit1;'#13#10 +
'interface'#13#10 +
'uses System.SysUtils, Unit2;'#13#10 +
'const'#13#10 +
' cDummy = 1;'#13#10 +
'var'#13#10 +
' G: Integer = 0;'#13#10 +
' Name: string = ''g'';'#13#10 +
'procedure Foo;'#13#10 +
'function Fn: Integer;'#13#10 +
'procedure Run;'#13#10 +
'implementation'#13#10 +
'procedure Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''global'');'#13#10 +
'end;'#13#10 +
'function Fn: Integer;'#13#10 +
'begin'#13#10 +
'  Result := 9;'#13#10 +
'end;'#13#10 +
'procedure Run;'#13#10 +
'var SR: TMySR;'#13#10 +
'begin'#13#10 +
'  SR := Default(TMySR);'#13#10 +
'  with SR do'#13#10 +
'    Foo;'#13#10 +
'  Writeln(G);'#13#10 +
'end;'#13#10 +
'end.'#13#10;
    lSecondSource :=
    'unit Unit2;'#13#10 +
'interface'#13#10 +
'type'#13#10 +
' TR = record'#13#10 +
'   procedure Foo; overload;'#13#10 +
'   procedure Foo(X: Integer); overload;'#13#10 +
'   function Fn: Integer; overload;'#13#10 +
'   function Fn(X: Integer): Integer; overload;'#13#10 +
' end;'#13#10 +
' TOther = record Z: Integer; end;'#13#10 +
' TMySR = type TR;'#13#10 +
'implementation'#13#10 +
'procedure TR.Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''member'');'#13#10 +
'end;'#13#10 +
'procedure TR.Foo(X: Integer);'#13#10 +
'begin'#13#10 +
'end;'#13#10 +
'function TR.Fn: Integer;'#13#10 +
'begin'#13#10 +
'  Result := 4;'#13#10 +
'end;'#13#10 +
'function TR.Fn(X: Integer): Integer;'#13#10 +
'begin'#13#10 +
'  Result := X;'#13#10 +
'end;'#13#10 +
'end.'#13#10;
    lRefused := True;
    lExpected := '';
    lExpectedEdits := 0;
    lExpectedLine := 25;
    lExpectedColumn := 3;
  end;
  if aShape = 'r6-control-plain-other-unit' then
  begin
    lSource :=
    'unit Unit1;'#13#10 +
'interface'#13#10 +
'uses System.SysUtils, Unit2;'#13#10 +
'const'#13#10 +
' cDummy = 1;'#13#10 +
'var'#13#10 +
' G: Integer = 0;'#13#10 +
' Name: string = ''g'';'#13#10 +
'procedure Foo;'#13#10 +
'function Fn: Integer;'#13#10 +
'procedure Run;'#13#10 +
'implementation'#13#10 +
'procedure Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''global'');'#13#10 +
'end;'#13#10 +
'function Fn: Integer;'#13#10 +
'begin'#13#10 +
'  Result := 9;'#13#10 +
'end;'#13#10 +
'procedure Run;'#13#10 +
'var SR: TR;'#13#10 +
'begin'#13#10 +
'  SR := Default(TR);'#13#10 +
'  with SR do'#13#10 +
'    Foo;'#13#10 +
'  Writeln(G);'#13#10 +
'end;'#13#10 +
'end.'#13#10;
    lSecondSource :=
    'unit Unit2;'#13#10 +
'interface'#13#10 +
'type'#13#10 +
' TR = record'#13#10 +
'   procedure Foo; overload;'#13#10 +
'   procedure Foo(X: Integer); overload;'#13#10 +
'   function Fn: Integer; overload;'#13#10 +
'   function Fn(X: Integer): Integer; overload;'#13#10 +
' end;'#13#10 +
' TOther = record Z: Integer; end;'#13#10 +
' TMySR = TR;'#13#10 +
'implementation'#13#10 +
'procedure TR.Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''member'');'#13#10 +
'end;'#13#10 +
'procedure TR.Foo(X: Integer);'#13#10 +
'begin'#13#10 +
'end;'#13#10 +
'function TR.Fn: Integer;'#13#10 +
'begin'#13#10 +
'  Result := 4;'#13#10 +
'end;'#13#10 +
'function TR.Fn(X: Integer): Integer;'#13#10 +
'begin'#13#10 +
'  Result := X;'#13#10 +
'end;'#13#10 +
'end.'#13#10;
    lRefused := False;
    lExpected := '  lWithRPtr := @SR;'#13#10 +
'  lWithRPtr^.Foo;';
    lExpectedEdits := 2;
    lExpectedLine := 25;
    lExpectedColumn := 3;
  end;
  if aShape = 'r6-control-weak-other-unit' then
  begin
    lSource :=
    'unit Unit1;'#13#10 +
'interface'#13#10 +
'uses System.SysUtils, Unit2;'#13#10 +
'const'#13#10 +
' cDummy = 1;'#13#10 +
'var'#13#10 +
' G: Integer = 0;'#13#10 +
' Name: string = ''g'';'#13#10 +
'procedure Foo;'#13#10 +
'function Fn: Integer;'#13#10 +
'procedure Run;'#13#10 +
'implementation'#13#10 +
'procedure Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''global'');'#13#10 +
'end;'#13#10 +
'function Fn: Integer;'#13#10 +
'begin'#13#10 +
'  Result := 9;'#13#10 +
'end;'#13#10 +
'procedure Run;'#13#10 +
'var SR: TMySR;'#13#10 +
'begin'#13#10 +
'  SR := Default(TMySR);'#13#10 +
'  with SR do'#13#10 +
'    Foo;'#13#10 +
'  Writeln(G);'#13#10 +
'end;'#13#10 +
'end.'#13#10;
    lSecondSource :=
    'unit Unit2;'#13#10 +
'interface'#13#10 +
'type'#13#10 +
' TR = record'#13#10 +
'   procedure Foo; overload;'#13#10 +
'   procedure Foo(X: Integer); overload;'#13#10 +
'   function Fn: Integer; overload;'#13#10 +
'   function Fn(X: Integer): Integer; overload;'#13#10 +
' end;'#13#10 +
' TOther = record Z: Integer; end;'#13#10 +
' TMySR = TR;'#13#10 +
'implementation'#13#10 +
'procedure TR.Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''member'');'#13#10 +
'end;'#13#10 +
'procedure TR.Foo(X: Integer);'#13#10 +
'begin'#13#10 +
'end;'#13#10 +
'function TR.Fn: Integer;'#13#10 +
'begin'#13#10 +
'  Result := 4;'#13#10 +
'end;'#13#10 +
'function TR.Fn(X: Integer): Integer;'#13#10 +
'begin'#13#10 +
'  Result := X;'#13#10 +
'end;'#13#10 +
'end.'#13#10;
    lRefused := False;
    lExpected := '  SR.Foo;';
    lExpectedEdits := 1;
    lExpectedLine := 25;
    lExpectedColumn := 3;
  end;
  if aShape = 'r6-inline-target' then
  begin
    lSource :=
    'unit Unit1;'#13#10 +
'interface'#13#10 +
'uses System.SysUtils;'#13#10 +
'type TR = record'#13#10 +
'   procedure Foo; overload;'#13#10 +
'   procedure Foo(X: Integer); overload;'#13#10 +
' end;'#13#10 +
' TMySR = TR;'#13#10 +
'var'#13#10 +
' G: Integer = 0;'#13#10 +
' Name: string = ''g'';'#13#10 +
'procedure Foo;'#13#10 +
'procedure Run;'#13#10 +
'implementation'#13#10 +
'procedure Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''global'');'#13#10 +
'end;'#13#10 +
'procedure TR.Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''member'');'#13#10 +
'end;'#13#10 +
'procedure TR.Foo(X: Integer);'#13#10 +
'begin'#13#10 +
'  Writeln(''member'', X);'#13#10 +
'end;'#13#10 +
'procedure Run;'#13#10 +
'var SR: TMySR;'#13#10 +
'begin'#13#10 +
'  SR := Default(TMySR);'#13#10 +
'  with SR do'#13#10 +
'    Foo;'#13#10 +
'  Writeln(''end'');'#13#10 +
'end;'#13#10 +
'end.'#13#10;
    lRefused := True;
    lExpected := '';
    lExpectedEdits := 0;
    lExpectedLine := 31;
    lExpectedColumn := 3;
  end;
  if aShape = 'r6-control-plain-inline-target' then
  begin
    lSource :=
    'unit Unit1;'#13#10 +
'interface'#13#10 +
'uses System.SysUtils;'#13#10 +
'type'#13#10 +
' TR = record'#13#10 +
'   procedure Foo; overload;'#13#10 +
'   procedure Foo(X: Integer); overload;'#13#10 +
' end;'#13#10 +
' TMySR = TR;'#13#10 +
'var'#13#10 +
' G: Integer = 0;'#13#10 +
' Name: string = ''g'';'#13#10 +
'procedure Foo;'#13#10 +
'procedure Run;'#13#10 +
'implementation'#13#10 +
'procedure Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''global'');'#13#10 +
'end;'#13#10 +
'procedure TR.Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''member'');'#13#10 +
'end;'#13#10 +
'procedure TR.Foo(X: Integer);'#13#10 +
'begin'#13#10 +
'  Writeln(''member'', X);'#13#10 +
'end;'#13#10 +
'procedure Run;'#13#10 +
'var SR: TR;'#13#10 +
'begin'#13#10 +
'  SR := Default(TR);'#13#10 +
'  with SR do'#13#10 +
'    Foo;'#13#10 +
'  Writeln(''end'');'#13#10 +
'end;'#13#10 +
'end.'#13#10;
    lRefused := False;
    lExpected := '  lWithRPtr := @SR;'#13#10 +
'  lWithRPtr^.Foo;';
    lExpectedEdits := 2;
    lExpectedLine := 32;
    lExpectedColumn := 3;
  end;
  if aShape = 'r6-control-weak-inline-target' then
  begin
    lSource :=
    'unit Unit1;'#13#10 +
'interface'#13#10 +
'uses System.SysUtils;'#13#10 +
'type'#13#10 +
' TR = record'#13#10 +
'   procedure Foo; overload;'#13#10 +
'   procedure Foo(X: Integer); overload;'#13#10 +
' end;'#13#10 +
' TMySR = TR;'#13#10 +
'var'#13#10 +
' G: Integer = 0;'#13#10 +
' Name: string = ''g'';'#13#10 +
'procedure Foo;'#13#10 +
'procedure Run;'#13#10 +
'implementation'#13#10 +
'procedure Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''global'');'#13#10 +
'end;'#13#10 +
'procedure TR.Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''member'');'#13#10 +
'end;'#13#10 +
'procedure TR.Foo(X: Integer);'#13#10 +
'begin'#13#10 +
'  Writeln(''member'', X);'#13#10 +
'end;'#13#10 +
'procedure Run;'#13#10 +
'var SR: TMySR;'#13#10 +
'begin'#13#10 +
'  SR := Default(TMySR);'#13#10 +
'  with SR do'#13#10 +
'    Foo;'#13#10 +
'  Writeln(''end'');'#13#10 +
'end;'#13#10 +
'end.'#13#10;
    lRefused := False;
    lExpected := '  SR.Foo;';
    lExpectedEdits := 1;
    lExpectedLine := 32;
    lExpectedColumn := 3;
  end;
  if aShape = 'r6-control-parenthesized' then
  begin
    lSource :=
    'unit Unit1;'#13#10 +
'interface'#13#10 +
'uses System.SysUtils;'#13#10 +
'type'#13#10 +
' TR = record'#13#10 +
'   procedure Foo; overload;'#13#10 +
'   procedure Foo(X: Integer); overload;'#13#10 +
' end;'#13#10 +
' TMySR = type TR;'#13#10 +
'var'#13#10 +
' G: Integer = 0;'#13#10 +
' Name: string = ''g'';'#13#10 +
'procedure Foo;'#13#10 +
'procedure Run;'#13#10 +
'implementation'#13#10 +
'procedure Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''global'');'#13#10 +
'end;'#13#10 +
'procedure TR.Foo;'#13#10 +
'begin'#13#10 +
'  Writeln(''member'');'#13#10 +
'end;'#13#10 +
'procedure TR.Foo(X: Integer);'#13#10 +
'begin'#13#10 +
'  Writeln(''member'', X);'#13#10 +
'end;'#13#10 +
'procedure Run;'#13#10 +
'var SR: TMySR;'#13#10 +
'begin'#13#10 +
'  SR := Default(TMySR);'#13#10 +
'  with SR do'#13#10 +
'    Foo(7);'#13#10 +
'  Writeln(''end'');'#13#10 +
'end;'#13#10 +
'end.'#13#10;
    lRefused := True;
    lExpected := '';
    lExpectedEdits := 0;
    lExpectedLine := 32;
    lExpectedColumn := 3;
  end;
  if aShape = 'r5-nested-different' then
  begin
    lSource := StringReplace(lSource, 'SR: TA;', 'SR: TA;'#13#10' SR2: TA;', []);
    lSource := StringReplace(lSource, 'with SR do with SR do', 'with SR do with SR2 do', []);
  end else if aShape = 'r5-nested-function' then
  begin
    lSource := StringReplace(lSource, 'procedure Run;'#13#10'implementation',
      'procedure Run;'#13#10'function GetSR: TA;'#13#10'implementation'#13#10 +
      'function GetSR: TA; begin Result := SR; end;', []);
    lSource := StringReplace(lSource, 'with SR do with SR do',
      'with GetSR do with GetSR do', []);
    lExpectedLine := 18;
  end;
  lWarmUnreachable := MatchText(aShape, ['control-opus-e7-forward-nested-strong-weak',
    'control-opus-e14-forward-two-level-strong-weak']);
  Assert.AreNotEqual('', lSource, aShape);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'), lSource, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P; uses Unit1; begin Run; end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dproj'),
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="Unit1.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  if lSecondSource <> '' then
  begin
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit2.pas'), lSecondSource, TEncoding.ASCII);
    TFile.WriteAllText(TPath.Combine(lRoot, 'P.dproj'),
      '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
      '<PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
      '<ItemGroup><DCCReference Include="Unit1.pas"/>' +
      '<DCCReference Include="Unit2.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  end;
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.Combine(lRoot, 'P.dproj');
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win64';
  lOptions.DelphiVersion := '23.0';
  lOptions.Cache.SqliteCacheFileName := TPath.Combine(lRoot, 'cache.sqlite');
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  if aShape = 'sol-clean-generic-indexed-write' then
    Assert.AreEqual('ALIAS_RECEIVER_MEMBERS_UNVERIFIED',
      ReasonOf(lFacts.Bindings[0], 'Values[0]', 'unsupported'));
  if StartsText('r5-', aShape) and (not StartsText('r5-nested-', aShape)) then
  begin
    lProjectionFound := False;
    for lSymbol in lFacts.Symbols do
      if SameText(lSymbol.Name, 'TA') and SameText(lSymbol.SymbolClass, 'type-member') then
        lProjectionFound := True;
    if StartsText('r5-newline-', aShape) then
      Assert.IsTrue(lProjectionFound, aShape + ': alias projection must exist')
    else
      Assert.IsFalse(lProjectionFound, aShape + ': missing projection must refuse');
  end;
  // Pin the binder's specific refusal independently of the planner backstop.
  if MatchText(aShape, ['r4-x1-strong-excludeattr', 'r4-x3-weak-of-strong-excl']) then
    Assert.AreEqual('ALIAS_RECEIVER_MEMBERS_UNVERIFIED',
      ReasonOf(lFacts.Bindings[0], 'ExcludeAttr', 'unsupported'));
  if MatchText(aShape, ['r4-x7-strong-name-plain', 'r4-x9-weak-of-strong-name']) then
    Assert.AreEqual('ALIAS_RECEIVER_MEMBERS_UNVERIFIED',
      ReasonOf(lFacts.Bindings[0], 'Name', 'unsupported'));
  if aShape = 'r4-x8-strong-size-plain' then
    Assert.AreEqual('ALIAS_RECEIVER_MEMBERS_UNVERIFIED',
      ReasonOf(lFacts.Bindings[0], 'Size', 'unsupported'));
  lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
  lSnapshotPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWithCompatibilitySnapshot(lFacts);
  if aMode = 'standalone' then
  begin
    lIdentity := Default(TDelphiSemanticSnapshotCacheIdentity);
    lIdentity.CacheKey := 'alias-receiver-proof';
    lIdentity.IdentityKey := lIdentity.CacheKey;
    lIdentity.SourceFileName := lOptions.ProjectFileName;
    lIdentity.FileHash := lFacts.ContextFingerprint;
    lIdentity.ContextHash := lFacts.ContextFingerprint;
    lIdentity.IncludeGraphHash := 'no-include-changes';
    lIdentity.SchemaVersion := 'alias-receiver-proof-v1';
    lStored := BuildCompatibilityRemoveWithPlanningSnapshotFromFacts(lFacts);
    try
      lCache := TDelphiSemanticSnapshotSqliteCache.Create(TPath.Combine(lRoot, 'standalone.sqlite'));
      try
        lCache.StoreProjectRemoveWithPlanningFacts(lIdentity, lStored, lFacts.Symbols);
        if lWarmUnreachable then
        begin
          // DS-743: the local weak-alias scope-chain guard rejects persisted facts.
          Assert.IsFalse(lCache.TryLoadProjectRemoveWithPlanningFacts(lIdentity, lLoaded));
          Assert.IsTrue(lLoaded = nil);
          Assert.AreEqual(0, lCache.Metrics.CacheHits);
          Assert.AreEqual(1, lCache.Metrics.CacheMisses);
          Assert.AreEqual(1, lCache.Metrics.Invalidations);
          lSnapshotPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
        end else begin
          Assert.IsTrue(lCache.TryLoadProjectRemoveWithPlanningFacts(lIdentity, lLoaded));
          try
            Assert.AreEqual(1, lCache.Metrics.CacheHits);
            Assert.AreEqual(0, lCache.Metrics.CacheMisses);
            Assert.AreEqual(0, lCache.Metrics.Invalidations);
            lSnapshotPlan := TDelphiSemanticRemoveWithPlanner.Plan(lLoaded);
          finally
            lLoaded.Free;
          end;
        end;
      finally
        lCache.Free;
      end;
    finally
      lStored.Free;
    end;
  end;
  if MatchText(aMode, ['sessioncold', 'sessionwarm']) then
    for var i := 0 to Ord(aMode = 'sessionwarm') do
    begin
      lSession := TDelphiSemanticProjectSession.Open(ProjectOptionsFromApiOptions(lOptions));
      try
        Assert.IsTrue(lSession.Success);
        lSessionBuild := lSession.Session.PlanRemoveWithResult;
        if lWarmUnreachable and (i = 1) then
        begin
          // DS-743 cold fallback, never counted as a persisted hit.
          Assert.AreEqual(0, lSessionBuild.SnapshotMetrics.SnapshotCacheHits);
          Assert.IsTrue(lSessionBuild.SnapshotMetrics.SnapshotCacheMisses > 0);
          Assert.IsTrue(lSessionBuild.SnapshotMetrics.SnapshotCacheInvalidations > 0);
        end else
          Assert.AreEqual(i, Integer(lSessionBuild.SnapshotMetrics.SnapshotCacheHits));
        lSnapshotPlan := lSessionBuild.Plan;
      finally
        lSession.Session.Free;
      end;
    end;
  GC(lSerializer, TJsonSerializer.Create, g);
  // Compatibility and snapshot planners intentionally identify their producer route.
  // The local standalone fallback is compared byte-for-byte without normalization.
  if lSnapshotPlan.BaselineSemanticModelVersion <> lPlan.BaselineSemanticModelVersion then
  begin
    Assert.AreEqual('project-snapshot-v1', lSnapshotPlan.BaselineSemanticModelVersion);
    lSnapshotPlan.BaselineSemanticModelVersion := lPlan.BaselineSemanticModelVersion;
  end;
  Assert.AreEqual(lSerializer.Serialize<TDelphiSemanticRemoveWithPlan>(lPlan),
    lSerializer.Serialize<TDelphiSemanticRemoveWithPlan>(lSnapshotPlan));
  Assert.AreEqual(lPlan.Status, lSnapshotPlan.Status);
  Assert.AreEqual(lPlan.ContextFingerprint, lSnapshotPlan.ContextFingerprint);
  Assert.AreEqual(Length(lPlan.Edits), Length(lSnapshotPlan.Edits));
  Assert.AreEqual(Length(lPlan.FinalStatements), Length(lSnapshotPlan.FinalStatements));
  for var i := 0 to High(lPlan.FinalStatements) do
  begin
    Assert.AreEqual(lPlan.FinalStatements[i].SemanticId, lSnapshotPlan.FinalStatements[i].SemanticId);
    Assert.AreEqual(lPlan.FinalStatements[i].Status, lSnapshotPlan.FinalStatements[i].Status);
    Assert.AreEqual(lPlan.FinalStatements[i].Reason, lSnapshotPlan.FinalStatements[i].Reason);
    Assert.AreEqual(lPlan.FinalStatements[i].SafetyReason, lSnapshotPlan.FinalStatements[i].SafetyReason);
    Assert.AreEqual(lPlan.FinalStatements[i].ReplacementText, lSnapshotPlan.FinalStatements[i].ReplacementText);
    Assert.AreEqual(Length(lPlan.FinalStatements[i].Temps), Length(lSnapshotPlan.FinalStatements[i].Temps));
    Assert.AreEqual(Length(lPlan.FinalStatements[i].Edits), Length(lSnapshotPlan.FinalStatements[i].Edits));
  end;
  if aMode <> 'cold' then
    lPlan := lSnapshotPlan;
  if MatchText(aShape, ['r5-nested-different', 'r5-nested-function']) then
  begin
    Assert.AreEqual(2, Integer(Length(lPlan.FinalStatements)));
    for var lCandidate in lPlan.Edits do
    begin
      Assert.AreEqual('remove-with-candidate', lCandidate.Kind);
      Assert.AreEqual(lCandidate.ExpectedSourceText, lCandidate.ReplacementText);
    end;
    for var i := 0 to High(lPlan.FinalStatements) do
    begin
      lInnerStatement := lPlan.FinalStatements[i];
      if aShape = 'r5-nested-function' then
      begin
        Assert.AreEqual('call-selector', lInnerStatement.Reason);
        Assert.AreEqual('call-selector', lInnerStatement.SafetyReason);
      end else begin
        Assert.AreEqual('selector-type-not-resolved', lInnerStatement.Reason);
        Assert.AreEqual('selector-type-not-resolved', lInnerStatement.SafetyReason);
      end;
      Assert.AreEqual('skipped', lInnerStatement.Status, lInnerStatement.Reason);
      Assert.AreEqual('', lInnerStatement.ReplacementText);
      Assert.AreEqual(0, Integer(Length(lInnerStatement.Edits)));
      Assert.AreEqual(0, Integer(Length(lInnerStatement.Temps)));
    end;
    Exit;
  end;
  if StartsText('r5-nested-', aShape) or (aShape = 'r6-nested') then
    Assert.AreEqual(2, Integer(Length(lPlan.FinalStatements)))
  else
    Assert.AreEqual(1, Integer(Length(lPlan.FinalStatements)));
  lStatement := lPlan.FinalStatements[0];
  Assert.IsTrue(SameText('Unit1.pas', TPath.GetFileName(lStatement.FileName)));
  Assert.AreEqual(lExpectedLine, lStatement.Range.StartLine);
  Assert.AreEqual(lExpectedColumn, lStatement.Range.StartColumn);
  Assert.AreNotEqual('', lStatement.SemanticId);
  if aShape = 'r5-nested-block' then
  begin
    lInnerStatement := lPlan.FinalStatements[1];
    Assert.AreEqual('planned', lInnerStatement.Status);
    Assert.AreEqual('  lWithOtherPtr := @O;'#13#10 +
      '  begin'#13#10 +
      '   Name := ''x''; lWithOtherPtr^.Z := 1;'#13#10 +
      '  end;', lInnerStatement.ReplacementText);
    Assert.AreEqual(2, Integer(Length(lInnerStatement.Edits)));
    Assert.AreEqual(1, Integer(Length(lInnerStatement.Temps)));
    Assert.AreEqual('declare-temp', lInnerStatement.Edits[0].Kind);
    Assert.AreEqual('var'#13#10 +
      '  lWithOtherPtr: ^TOther;'#13#10 +
      '', lInnerStatement.Edits[0].ReplacementText);
    Assert.AreEqual(lInnerStatement.FileName, lInnerStatement.Edits[0].FileName);
    Assert.AreEqual(14, lInnerStatement.Edits[0].Range.StartLine);
    Assert.AreEqual(1, lInnerStatement.Edits[0].Range.StartColumn);
    Assert.AreEqual(14, lInnerStatement.Edits[0].Range.EndLine);
    Assert.AreEqual(1, lInnerStatement.Edits[0].Range.EndColumn);
    Assert.AreEqual('replace-statement', lInnerStatement.Edits[1].Kind);
    Assert.AreEqual('  lWithOtherPtr := @O;'#13#10 +
      '  begin'#13#10 +
      '   Name := ''x''; lWithOtherPtr^.Z := 1;'#13#10 +
      '  end;', lInnerStatement.Edits[1].ReplacementText);
    Assert.AreEqual(lInnerStatement.FileName, lInnerStatement.Edits[1].FileName);
    Assert.AreEqual(18, lInnerStatement.Edits[1].Range.StartLine);
    Assert.AreEqual(1, lInnerStatement.Edits[1].Range.StartColumn);
    Assert.AreEqual(21, lInnerStatement.Edits[1].Range.EndLine);
    Assert.AreEqual(6, lInnerStatement.Edits[1].Range.EndColumn);
    Assert.AreEqual(1, Integer(Length(lPlan.Edits)), aShape + ': inner plan candidate');
    Assert.AreEqual('remove-with-candidate', lPlan.Edits[0].Kind);
    Assert.AreEqual('requires-dak-compatibility-adapter', lPlan.Edits[0].ApplyMode);
    Assert.AreEqual(lInnerStatement.SemanticId, lPlan.Edits[0].StatementId);
    Assert.AreEqual(lInnerStatement.FileName, lPlan.Edits[0].FileName);
    Assert.AreEqual(lPlan.Edits[0].ExpectedSourceText, lPlan.Edits[0].ReplacementText);
    Assert.AreNotEqual('', lPlan.Edits[0].ExpectedSourceText);
    Assert.AreEqual(lInnerStatement.Range.StartLine, lPlan.Edits[0].Range.StartLine);
    Assert.AreEqual(lInnerStatement.Range.StartColumn, lPlan.Edits[0].Range.StartColumn);
    Assert.AreEqual(lInnerStatement.Range.EndLine, lPlan.Edits[0].Range.EndLine);
    Assert.AreEqual(lInnerStatement.Range.EndColumn, lPlan.Edits[0].Range.EndColumn);
  end;
  if aShape = 'r5-nested-repeat' then
  begin
    lInnerStatement := lPlan.FinalStatements[1];
    Assert.AreEqual('planned', lInnerStatement.Status);
    Assert.AreEqual(' Name := ''x'';', lInnerStatement.ReplacementText);
    Assert.AreEqual(1, Integer(Length(lInnerStatement.Edits)));
    Assert.AreEqual(0, Integer(Length(lInnerStatement.Temps)));
    Assert.AreEqual('replace-statement', lInnerStatement.Edits[0].Kind);
    Assert.AreEqual(' Name := ''x'';', lInnerStatement.Edits[0].ReplacementText);
    Assert.AreEqual(lInnerStatement.FileName, lInnerStatement.Edits[0].FileName);
    Assert.AreEqual(16, lInnerStatement.Edits[0].Range.StartLine);
    Assert.AreEqual(13, lInnerStatement.Edits[0].Range.StartColumn);
    Assert.AreEqual(16, lInnerStatement.Edits[0].Range.EndLine);
    Assert.AreEqual(35, lInnerStatement.Edits[0].Range.EndColumn);
    Assert.AreEqual(1, Integer(Length(lPlan.Edits)), aShape + ': inner plan candidate');
    Assert.AreEqual('remove-with-candidate', lPlan.Edits[0].Kind);
    Assert.AreEqual('requires-dak-compatibility-adapter', lPlan.Edits[0].ApplyMode);
    Assert.AreEqual(lInnerStatement.SemanticId, lPlan.Edits[0].StatementId);
    Assert.AreEqual(lInnerStatement.FileName, lPlan.Edits[0].FileName);
    Assert.AreEqual(lPlan.Edits[0].ExpectedSourceText, lPlan.Edits[0].ReplacementText);
    Assert.AreNotEqual('', lPlan.Edits[0].ExpectedSourceText);
    Assert.AreEqual(lInnerStatement.Range.StartLine, lPlan.Edits[0].Range.StartLine);
    Assert.AreEqual(lInnerStatement.Range.StartColumn, lPlan.Edits[0].Range.StartColumn);
    Assert.AreEqual(lInnerStatement.Range.EndLine, lPlan.Edits[0].Range.EndLine);
    Assert.AreEqual(lInnerStatement.Range.EndColumn, lPlan.Edits[0].Range.EndColumn);
  end;
  if aShape = 'r5-nested-single' then
  begin
    lInnerStatement := lPlan.FinalStatements[1];
    Assert.AreEqual('planned', lInnerStatement.Status);
    Assert.AreEqual('begin'#13#10 +
      '            lWithOtherPtr := @O;'#13#10 +
      ' Name := ''x'';'#13#10 +
      '            end;', lInnerStatement.ReplacementText);
    Assert.AreEqual(2, Integer(Length(lInnerStatement.Edits)));
    Assert.AreEqual(1, Integer(Length(lInnerStatement.Temps)));
    Assert.AreEqual('declare-temp', lInnerStatement.Edits[0].Kind);
    Assert.AreEqual('var'#13#10 +
      '  lWithOtherPtr: ^TOther;'#13#10 +
      '', lInnerStatement.Edits[0].ReplacementText);
    Assert.AreEqual(lInnerStatement.FileName, lInnerStatement.Edits[0].FileName);
    Assert.AreEqual(14, lInnerStatement.Edits[0].Range.StartLine);
    Assert.AreEqual(1, lInnerStatement.Edits[0].Range.StartColumn);
    Assert.AreEqual(14, lInnerStatement.Edits[0].Range.EndLine);
    Assert.AreEqual(1, lInnerStatement.Edits[0].Range.EndColumn);
    Assert.AreEqual('replace-statement', lInnerStatement.Edits[1].Kind);
    Assert.AreEqual('begin'#13#10 +
      '            lWithOtherPtr := @O;'#13#10 +
      ' Name := ''x'';'#13#10 +
      '            end;', lInnerStatement.Edits[1].ReplacementText);
    Assert.AreEqual(lInnerStatement.FileName, lInnerStatement.Edits[1].FileName);
    Assert.AreEqual(16, lInnerStatement.Edits[1].Range.StartLine);
    Assert.AreEqual(13, lInnerStatement.Edits[1].Range.StartColumn);
    Assert.AreEqual(16, lInnerStatement.Edits[1].Range.EndLine);
    Assert.AreEqual(34, lInnerStatement.Edits[1].Range.EndColumn);
    Assert.AreEqual(1, Integer(Length(lPlan.Edits)), aShape + ': inner plan candidate');
    Assert.AreEqual('remove-with-candidate', lPlan.Edits[0].Kind);
    Assert.AreEqual('requires-dak-compatibility-adapter', lPlan.Edits[0].ApplyMode);
    Assert.AreEqual(lInnerStatement.SemanticId, lPlan.Edits[0].StatementId);
    Assert.AreEqual(lInnerStatement.FileName, lPlan.Edits[0].FileName);
    Assert.AreEqual(lPlan.Edits[0].ExpectedSourceText, lPlan.Edits[0].ReplacementText);
    Assert.AreNotEqual('', lPlan.Edits[0].ExpectedSourceText);
    Assert.AreEqual(lInnerStatement.Range.StartLine, lPlan.Edits[0].Range.StartLine);
    Assert.AreEqual(lInnerStatement.Range.StartColumn, lPlan.Edits[0].Range.StartColumn);
    Assert.AreEqual(lInnerStatement.Range.EndLine, lPlan.Edits[0].Range.EndLine);
    Assert.AreEqual(lInnerStatement.Range.EndColumn, lPlan.Edits[0].Range.EndColumn);
  end;
  if aShape = 'r5-nested-weak-strong' then
  begin
    lInnerStatement := lPlan.FinalStatements[1];
    Assert.AreEqual('planned', lInnerStatement.Status);
    Assert.AreEqual('begin'#13#10 +
      '            lWithOtherPtr := @O;'#13#10 +
      ' Name := ''x'';'#13#10 +
      '            end;', lInnerStatement.ReplacementText);
    Assert.AreEqual(2, Integer(Length(lInnerStatement.Edits)));
    Assert.AreEqual(1, Integer(Length(lInnerStatement.Temps)));
    Assert.AreEqual('declare-temp', lInnerStatement.Edits[0].Kind);
    Assert.AreEqual('var'#13#10 +
      '  lWithOtherPtr: ^TOther;'#13#10 +
      '', lInnerStatement.Edits[0].ReplacementText);
    Assert.AreEqual(lInnerStatement.FileName, lInnerStatement.Edits[0].FileName);
    Assert.AreEqual(15, lInnerStatement.Edits[0].Range.StartLine);
    Assert.AreEqual(1, lInnerStatement.Edits[0].Range.StartColumn);
    Assert.AreEqual(15, lInnerStatement.Edits[0].Range.EndLine);
    Assert.AreEqual(1, lInnerStatement.Edits[0].Range.EndColumn);
    Assert.AreEqual('replace-statement', lInnerStatement.Edits[1].Kind);
    Assert.AreEqual('begin'#13#10 +
      '            lWithOtherPtr := @O;'#13#10 +
      ' Name := ''x'';'#13#10 +
      '            end;', lInnerStatement.Edits[1].ReplacementText);
    Assert.AreEqual(lInnerStatement.FileName, lInnerStatement.Edits[1].FileName);
    Assert.AreEqual(17, lInnerStatement.Edits[1].Range.StartLine);
    Assert.AreEqual(13, lInnerStatement.Edits[1].Range.StartColumn);
    Assert.AreEqual(17, lInnerStatement.Edits[1].Range.EndLine);
    Assert.AreEqual(34, lInnerStatement.Edits[1].Range.EndColumn);
    Assert.AreEqual(1, Integer(Length(lPlan.Edits)), aShape + ': inner plan candidate');
    Assert.AreEqual('remove-with-candidate', lPlan.Edits[0].Kind);
    Assert.AreEqual('requires-dak-compatibility-adapter', lPlan.Edits[0].ApplyMode);
    Assert.AreEqual(lInnerStatement.SemanticId, lPlan.Edits[0].StatementId);
    Assert.AreEqual(lInnerStatement.FileName, lPlan.Edits[0].FileName);
    Assert.AreEqual(lPlan.Edits[0].ExpectedSourceText, lPlan.Edits[0].ReplacementText);
    Assert.AreNotEqual('', lPlan.Edits[0].ExpectedSourceText);
    Assert.AreEqual(lInnerStatement.Range.StartLine, lPlan.Edits[0].Range.StartLine);
    Assert.AreEqual(lInnerStatement.Range.StartColumn, lPlan.Edits[0].Range.StartColumn);
    Assert.AreEqual(lInnerStatement.Range.EndLine, lPlan.Edits[0].Range.EndLine);
    Assert.AreEqual(lInnerStatement.Range.EndColumn, lPlan.Edits[0].Range.EndColumn);
  end;
  if aShape = 'r6-nested' then
  begin
    lInnerStatement := lPlan.FinalStatements[1];
    Assert.AreEqual('planned', lInnerStatement.Status);
    Assert.AreEqual('    begin'#13#10 +
      '      lWithOtherPtr := @O;'#13#10 +
      '      begin'#13#10 +
      '      lWithOtherPtr^.Z := 1;'#13#10 +
      '      Foo;'#13#10 +
      '    end;'#13#10 +
      '    end;', lInnerStatement.ReplacementText);
    Assert.AreEqual(2, Integer(Length(lInnerStatement.Edits)));
    Assert.AreEqual(1, Integer(Length(lInnerStatement.Temps)));
    Assert.AreEqual('declare-temp', lInnerStatement.Edits[0].Kind);
    Assert.AreEqual('var'#13#10 +
      '  lWithOtherPtr: ^TOther;'#13#10 +
      '', lInnerStatement.Edits[0].ReplacementText);
    Assert.AreEqual(lInnerStatement.FileName, lInnerStatement.Edits[0].FileName);
    Assert.AreEqual(45, lInnerStatement.Edits[0].Range.StartLine);
    Assert.AreEqual(1, lInnerStatement.Edits[0].Range.StartColumn);
    Assert.AreEqual(45, lInnerStatement.Edits[0].Range.EndLine);
    Assert.AreEqual(1, lInnerStatement.Edits[0].Range.EndColumn);
    Assert.AreEqual('replace-statement', lInnerStatement.Edits[1].Kind);
    Assert.AreEqual('    begin'#13#10 +
      '      lWithOtherPtr := @O;'#13#10 +
      '      begin'#13#10 +
      '      lWithOtherPtr^.Z := 1;'#13#10 +
      '      Foo;'#13#10 +
      '    end;'#13#10 +
      '    end;', lInnerStatement.Edits[1].ReplacementText);
    Assert.AreEqual(lInnerStatement.FileName, lInnerStatement.Edits[1].FileName);
    Assert.AreEqual(48, lInnerStatement.Edits[1].Range.StartLine);
    Assert.AreEqual(1, lInnerStatement.Edits[1].Range.StartColumn);
    Assert.AreEqual(52, lInnerStatement.Edits[1].Range.EndLine);
    Assert.AreEqual(8, lInnerStatement.Edits[1].Range.EndColumn);
    Assert.AreEqual(1, Integer(Length(lPlan.Edits)), aShape + ': inner plan candidate');
    Assert.AreEqual('remove-with-candidate', lPlan.Edits[0].Kind);
    Assert.AreEqual('requires-dak-compatibility-adapter', lPlan.Edits[0].ApplyMode);
    Assert.AreEqual(lInnerStatement.SemanticId, lPlan.Edits[0].StatementId);
    Assert.AreEqual(lInnerStatement.FileName, lPlan.Edits[0].FileName);
    Assert.AreEqual(lPlan.Edits[0].ExpectedSourceText, lPlan.Edits[0].ReplacementText);
    Assert.AreNotEqual('', lPlan.Edits[0].ExpectedSourceText);
    Assert.AreEqual(lInnerStatement.Range.StartLine, lPlan.Edits[0].Range.StartLine);
    Assert.AreEqual(lInnerStatement.Range.StartColumn, lPlan.Edits[0].Range.StartColumn);
    Assert.AreEqual(lInnerStatement.Range.EndLine, lPlan.Edits[0].Range.EndLine);
    Assert.AreEqual(lInnerStatement.Range.EndColumn, lPlan.Edits[0].Range.EndColumn);
  end;
  if not lRefused then
  begin
    Assert.AreEqual('planned', lStatement.Status, aShape + ': ' + lStatement.Reason);
    Assert.AreEqual(lExpected, lStatement.ReplacementText);
    Assert.AreEqual(lExpectedEdits, Integer(Length(lStatement.Edits)));
    Exit;
  end;
  Assert.AreEqual('skipped', lStatement.Status, aShape + ': ' + lStatement.Reason);
  if lLocal then
    Assert.AreEqual('ROUTINE_LOCAL_TYPE_UNSUPPORTED', lStatement.SafetyReason)
  else if MatchText(aShape, ['r5-multi-name', 'r5-multi-size', 'r5-multi-indexed',
    'r5-comment-name', 'r5-comment-size', 'r5-comment-indexed',
    'r5-chain-second-name', 'r5-chain-second-size', 'r5-chain-second-indexed']) then
    Assert.AreEqual('type-source-not-indexed', lStatement.SafetyReason)
  else
    Assert.AreEqual('ALIAS_RECEIVER_MEMBERS_UNVERIFIED', lStatement.SafetyReason);
  Assert.AreEqual('', lStatement.ReplacementText);
  Assert.AreEqual(0, Integer(Length(lStatement.Edits)), aShape + ': statement Edits');
  Assert.AreEqual(0, Integer(Length(lStatement.Temps)), aShape + ': statement Temps');
  if MatchText(aShape, ['r5-multi-name', 'r5-multi-size', 'r5-multi-indexed',
    'r5-comment-name', 'r5-comment-size', 'r5-comment-indexed',
    'r5-chain-second-name', 'r5-chain-second-size', 'r5-chain-second-indexed']) then
  begin
    // The compatibility candidate is bookkeeping; it must preserve every source byte.
    Assert.AreEqual(1, Integer(Length(lPlan.Edits)), aShape + ': no-op plan candidate');
    Assert.AreEqual('remove-with-candidate', lPlan.Edits[0].Kind);
    Assert.AreEqual('requires-dak-compatibility-adapter', lPlan.Edits[0].ApplyMode);
    Assert.AreEqual(lStatement.SemanticId, lPlan.Edits[0].StatementId);
    Assert.AreEqual(lStatement.FileName, lPlan.Edits[0].FileName);
    Assert.AreEqual(lStatement.Range.StartLine, lPlan.Edits[0].Range.StartLine);
    Assert.AreEqual(lStatement.Range.StartColumn, lPlan.Edits[0].Range.StartColumn);
    Assert.AreEqual(lStatement.Range.EndLine, lPlan.Edits[0].Range.EndLine);
    Assert.AreEqual(lStatement.Range.EndColumn, lPlan.Edits[0].Range.EndColumn);
    Assert.AreEqual(lPlan.Edits[0].ExpectedSourceText, lPlan.Edits[0].ReplacementText);
    Assert.AreNotEqual('', lPlan.Edits[0].ExpectedSourceText);
  end else if (not StartsText('r5-nested-', aShape)) and (aShape <> 'r6-nested') then
    Assert.AreEqual(0, Integer(Length(lPlan.Edits)), aShape + ': plan Edits');
end;

procedure TWithBinderTests.AliasRefusalPreservesLocalTypeReason;
var
  lRoot: string;
  lOptions: TDelphiSemanticApiOptions;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
begin
  lRoot := WithBinderTempPath('DS741-alias-refusal-precedence');
  TDirectory.CreateDirectory(lRoot);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
    'unit Unit1;'#13#10 +
    'interface procedure Run;'#13#10 +
    'implementation'#13#10 +
    'procedure Run;'#13#10 +
    'type TAlias = TUnknown;'#13#10 +
    'var Item: TAlias;'#13#10 +
    'begin with Item do Caption := 1; end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P; uses Unit1; begin Run; end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dproj'),
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="Unit1.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.Combine(lRoot, 'P.dproj');
  lOptions.DelphiVersion := '23.0';
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  Assert.AreEqual(1, Integer(Length(lFacts.Bindings)));
  Assert.AreEqual('unsupported', lFacts.Bindings[0].Selectors[0].Status);
  Assert.AreEqual('ROUTINE_LOCAL_TYPE_UNSUPPORTED',
    lFacts.Bindings[0].Selectors[0].ReasonCode);
  Assert.AreEqual('ROUTINE_LOCAL_TYPE_UNSUPPORTED', ReasonOf(lFacts.Bindings[0], 'Caption', 'unsupported'));
end;

procedure TWithBinderTests.AliasReceiverUnverifiedFamiliesRemainRefused(const aShape, aMode: string);
begin
  ValueMembersColdWarmSnapshot(aShape, aMode);
end;

function DS741ExpectedReplacement(const aShape: string): string;
begin
  Result := '';
  if aShape = 'partial-weak-global' then
    Exit(
      ' Item.A := Item.Count;');
  if aShape = 'partial-weak-noglobal' then
    Exit(
      ' Item.A := Item.Count;');
  if aShape = 'partial-strong-global' then
    Exit(
      ' Item.A := Item.Count;');
  if aShape = 'strong-alias-qualified-target' then
    Exit(
      ' Rec.A := Rec.Count;');
  if aShape = 'nested-parent-trigger' then
    Exit(
      ' begin Writeln(Item.Count);                                      lWithOtherPtr := @Other;'#13#10 +
      ' Item.A := lWithOtherPtr^.B; end;');
  if aShape = 'nested-parent-noglobal' then
    Exit(
      ' begin Writeln(Item.Count);                                      lWithOtherPtr := @Other;'#13#10 +
      ' Item.A := lWithOtherPtr^.B; end;');
  if aShape = 'nested-child-trigger' then
    Exit(
      ' begin Item.A := 5;                              lWithOtherPtr := @Other;'#13#10 +
      ' lWithOtherPtr^.B := Item.Count; end;');
  if aShape = 'nested-three-level' then
    Exit(
      ' begin Item.A := 5;                              lWithOtherPtr := @Other;'#13#10 +
      ' begin                                                  lWithExtraPtr := @Extra;'#13#10 +
      ' lWithExtraPtr^.C := Item.Count; end; end;');
  if aShape = 'nested-siblings' then
    Exit(
      ' begin                      lWithOtherPtr := @Other;'#13#10 +
      ' lWithOtherPtr^.B := Item.Count;                                                lWithExtraPtr := @Extra;'#13#10 +
      ' lWithExtraPtr^.C := Item.A; end;');
  if aShape = 'partial-noconst-control' then
    Exit(
      ' Item.A := 7;');
  if aShape = 'nested-unrelated-control' then
    Exit(
      ' begin Item.A := Item.Count;                                  lWithOtherPtr := @Other;'#13#10 +
      ' lWithOtherPtr^.B := 1; end;');
  if aShape = 'partial-cascade' then
    Exit(
      ' begin Item.A := 5;                            lWithOtherPtr := @Other;'#13#10 +
      ' lWithOtherPtr^.B := Item.Count; try Item.A := 6; except on Exception do begin'#13#10 +
      '                                                                                        lWithExtraPtr := @Extra;'#13#10 +
      ' lWithExtraPtr^.C := 1;'#13#10 +
      '                                                                                        end; end; end;');
end;

procedure TWithBinderTests.ValueMembersColdWarmSnapshot(const aShape, aMode: string);
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticApiOptions;
  lPlan, lSnapshotPlan: TDelphiSemanticRemoveWithPlan;
  lRoot, lType, lGlobal, lLocal, lBody, lExpected, lImplementation: string;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lStored, lLoaded: TDelphiProjectSnapshot;
  lShape, lSource: string;
  lStatement, lInnerStatement: TDelphiSemanticRemoveWithFinalStatement;
  lSession: TDelphiSemanticProjectSessionResult;
  lSessionBuild: TDelphiSemanticRemoveWithPlanBuildResult;
  lExpectedStatements, lMatchedStatements, lMatches: Integer;
begin
  lRoot := WithBinderTempPath('DS731-persistence-' + aShape + '-' + aMode);
  TDirectory.CreateDirectory(lRoot);
  lShape := aShape;
  if aShape = 'rmpv-compiling-anon-field' then
    lShape := 'anon-partial-field';
  if StartsText('inactive-tag-', aShape) then
    lShape := 'anonymous-inactive';
  lType := 'var'#13#10'  Rec: record'#13#10'    A: Integer;'#13#10 +
    '    case Count: Integer of'#13#10'      0: (X: Integer);'#13#10'  end;';
  lGlobal := '';
  lLocal := '';
  lImplementation := '';
  lBody := 'with Rec do A := Count;';
  lExpected := 'Rec.A := Rec.Count;';
  if lShape = 'anonymous-global' then
    lGlobal := 'var Count: Integer;';
  if lShape = 'anonymous-local' then
    lLocal := 'var Count: Integer;';
  if lShape = 'num-rec' then
  begin
    lType := '';
    lLocal := 'var'#13#10'  num_rec: packed record'#13#10'    ll: Integer;'#13#10 +
      '    case n_id: Byte of'#13#10'      0: (r_b: Byte);'#13#10 +
      '      1: (r_w: Word);'#13#10'  end;';
    lBody := 'with num_rec do ll := n_id;';
    lExpected := 'num_rec.ll := num_rec.n_id;';
  end;
  if MatchText(lShape, ['indexed-named-tag', 'indexed-inline-tag',
    'strong-alias-qualified-target']) then
  begin
    lType := 'type TRec = record A: Integer; case Count: Integer of 0: (X: Integer); end;';
    lGlobal := 'var Count: Integer;';
    if lShape = 'strong-alias-qualified-target' then
    begin
      lType := lType + #13#10'  TAlias = type TRec;'#13#10'var Rec: TAlias;';
      lBody := '  with Rec do Rec.A := Count;';
    end else begin
      if lShape = 'indexed-inline-tag' then
        lType := lType.Replace('case Count:',
          'case {$IFDEF NEVER_DS731}RealTag{$ELSE}Count{$ENDIF}:');
      lLocal := 'var lItems: TArray<TRec>; lIndex: Integer;';
      lBody := '  with lItems[lIndex] do A := Count;';
    end;
  end;
  if lShape = 'indexed-field-control' then
  begin
    lType := 'type TRec = record A: Integer; end;';
    lLocal := 'var lItems: TArray<TRec>; lIndex: Integer;';
    lBody := '  with lItems[lIndex] do A := 1;';
    lExpected := 'lWithRecPtr^.A := 1;';
  end;
  if MatchText(lShape, ['unrelated-diagnostic', 'receiver-diagnostic']) then
  begin
    lType := 'type'#13#10'  TItem = record'#13#10'    A: Integer;'#13#10'  end;'#13#10 +
      '  TUnrelated = record'#13#10'    Items: array[0..1] of Integer'#13#10'  end;'#13#10 +
      'var Item: TItem;';
    if lShape = 'receiver-diagnostic' then
      lType := lType.Replace('    A: Integer;',
        '    A: Integer;'#13#10'    Items: array[0..1] of Integer');
    lGlobal := 'var Count: Integer;';
    lBody := 'with Item do A := Count;';
    lExpected := 'lWithItemPtr^.A := Count;';
  end;
  if StartsText('class-', lShape) and (lShape <> 'class-var') then
  begin
    lType := 'type'#13#10'  TItem = class(TObject)'#13#10'    A: Integer;'#13#10'  end;'#13#10 +
      'var Item: TItem;';
    if lShape = 'class-interfaced' then
      lType := lType.Replace('class(TObject)', 'class(TInterfacedObject)');
    if lShape = 'class-component' then
      lType := 'uses System.Classes;'#13#10 +
        lType.Replace('class(TObject)', 'class(TComponent)');
    if lShape = 'class-forward' then
      lType := 'type'#13#10'  TBase = class;'#13#10 +
        '  TBase = class(TObject)'#13#10'  end;'#13#10 +
        '  TItem = class(TBase)'#13#10'    A: Integer;'#13#10'  end;'#13#10 +
        'var Item: TItem;';
    lGlobal := 'var Count: Integer;';
    lBody := 'with Item do A := Count;';
    lExpected := 'lWithItem.A := Count;';
  end;
  if StartsText('partial-', lShape) then
  begin
    lType := 'type'#13#10'  TItem = record'#13#10'    var A: Integer;'#13#10 +
      '    const Count = 7;'#13#10'  end;'#13#10'  TAlias = TItem;'#13#10 +
      'var Item: TAlias;';
    lGlobal := 'var A: Integer; Count: Integer;';
    lBody := 'with Item do A := Count;';
    lExpected := 'A := 7;';
    if lShape = 'partial-weak-noglobal' then
      lGlobal := 'var Count: Integer;';
    if lShape = 'partial-strong-global' then
      lType := lType.Replace('TAlias = TItem;', 'TAlias = type TItem;');
    if lShape = 'partial-noconst-control' then
    begin
      lType := lType.Replace('    const Count = 7;'#13#10, '');
      lBody := 'with Item do A := 7;';
    end;
    if lShape = 'partial-verified-control' then
    begin
      lType := lType.Replace('var A: Integer;', 'A: Integer;');
      lExpected := 'Item.A := Item.Count;';
    end;
  end;
  if StartsText('partial-root-', lShape) then
  begin
    lType := 'type'#13#10'  TItem = class(TObject)'#13#10'    A: Integer;'#13#10 +
      '    const Count = 7;'#13#10'  end;'#13#10'var Item: TItem;';
    if lShape = 'partial-root-interfaced' then
      lType := lType.Replace('class(TObject)', 'class(TInterfacedObject)');
    if lShape = 'partial-root-component' then
      lType := 'uses System.Classes;'#13#10 +
        lType.Replace('class(TObject)', 'class(TComponent)');
    lGlobal := 'var X: Integer;';
    lBody := 'with Item do A := Count + X;';
    lExpected := 'lWithItem.A := lWithItem.Count + X;';
  end;
  if lShape = 'partial-indexed-ancestor' then
  begin
    // The indexed forward ancestor has no verified body. This is distinct
    // from the unindexed RTL root and must not authorize a partial rewrite.
    lType := 'type'#13#10'  TBase = class;'#13#10 +
      '  TItem = class(TBase)'#13#10'    const Count = 7;'#13#10'  end;'#13#10 +
      'var Item: TItem;';
    lGlobal := 'var X: Integer;';
    lBody := 'with Item do A := Count + X;';
  end;
  if StartsText('homonym-', lShape) then
  begin
    lType := 'type'#13#10'  TItem = record'#13#10'    A: Integer;'#13#10'  end;'#13#10 +
      'var Item: TItem;';
    if lShape = 'homonym-tag' then
      lType := lType.Replace('    A: Integer;',
        '    A: Integer;'#13#10'    case Count: Integer of 0: (X: Integer);');
    if lShape = 'homonym-constant' then
      lType := lType.Replace('    A: Integer;',
        '    var A: Integer;'#13#10'    const Count = 7;');
    lGlobal := 'const Count = 100;';
    lBody := 'with Item do A := Count;';
    lExpected := 'lWithItemPtr^.A := Count;';
    if MatchText(lShape, ['homonym-tag', 'homonym-constant']) then
      lExpected := 'lWithItemPtr^.A := lWithItemPtr^.Count;';
    if lShape = 'homonym-unverified' then
    begin
      lLocal := 'var lItems: TArray<TItem>; lIndex: Integer;';
      lBody := 'with lItems[lIndex] do A := Count;';
    end;
  end;
  if StartsText('nested-', lShape) then
  begin
    lType := 'type'#13#10'  TItem = record'#13#10'    var A: Integer;'#13#10 +
      '    const Count = 7;'#13#10'  end;'#13#10'  TAlias = TItem;'#13#10 +
      '  TOther = record B: Integer; end;'#13#10 +
      '  TExtra = record C: Integer; end;'#13#10 +
      'var'#13#10'  Item: TAlias;'#13#10'  Other: TOther;'#13#10'  Extra: TExtra;';
    lGlobal := 'var A: Integer; Count: Integer;';
    lBody := 'with Item do begin Writeln(Count); with Other do A := B; end;';
    if lShape = 'nested-parent-noglobal' then
      lGlobal := 'var Count: Integer;';
    if lShape = 'nested-child-trigger' then
      lBody := 'with Item do begin A := 5; with Other do B := Count; end;';
    if lShape = 'nested-three-level' then
      lBody := 'with Item do begin A := 5; with Other do begin ' +
        'with Extra do C := Count; end; end;';
    if lShape = 'nested-siblings' then
      lBody := 'with Item do begin with Other do B := Count; ' +
        'with Extra do C := A; end;';
    if lShape = 'nested-verified-control' then
    begin
      lType := lType.Replace('var A: Integer;', 'A: Integer;');
      lBody := 'with Item do begin A := 5; with Other do B := Count; end;';
      lExpected := 'lWithOtherPtr^.B := Item.Count;';
    end;
    if lShape = 'nested-unrelated-control' then
    begin
      lType := lType.Replace('var A: Integer;', 'A: Integer;').Replace(
        'TOther = record B: Integer; end;',
        'TOther = record'#13#10'    var B: Integer;'#13#10'  end;');
      lBody := 'with Item do begin A := Count; with Other do B := 1; end;';
      // Characterization only: Other has no slice qualification. Its pre-existing
      // bare field defect must not be attributed to Item's verified member set.
      lExpected := 'B := 1;';
    end;
  end;
  if StartsText('anon-', lShape) then
  begin
    lType := 'var'#13#10'  Rec: record'#13#10'    A: Integer;'#13#10 +
      '    case Count: Integer of'#13#10'      0: (X: Integer);'#13#10'  end;';
    lLocal := 'var lOutside: Integer;';
    lBody := 'with Rec do begin A := Count; lOutside := 1; end;';
    lExpected := 'Rec.A := Rec.Count; lOutside := 1;';
    if MatchText(lShape, ['anon-partial-field', 'anon-partial-enum']) then
    begin
      // The anonymous tag takes D3 while VAR field inventory is unverified.
      lType := lType.Replace('    A: Integer;', '    var A: Integer;');
      lBody := 'with Rec do A := Count;';
      if lShape = 'anon-partial-enum' then
      begin
        lType := lType.Replace('var A: Integer;', 'var A: (Zero, One);');
        lBody := 'with Rec do begin A := Low(A); X := Count; end;';
      end;
    end;
    if lShape = 'anon-partial-include' then
    begin
      lType := lType.Replace('    case Count:', '    {$I extra.inc}'#13#10'    case Count:');
      TFile.WriteAllText(TPath.Combine(lRoot, 'extra.inc'), 'Hidden: Integer;', TEncoding.ASCII);
    end;
    if lShape = 'anon-pointer-control' then
    begin
      // A pointer form is not a record witness unless its declaration is proven.
      lType := lType.Replace('Rec: record', 'Rec: ^record');
      lBody := 'with Rec^ do begin A := Count; lOutside := 1; end;';
    end;
  end;
  if EndsText('-forward-ancestor', lShape) then
  begin
    // DS-741 Q2: retain RMPV for the partial, nested and cascade families.
    lType := 'type'#13#10'  TBase = class;'#13#10 +
      '  TItem = class(TBase)'#13#10'    const Count = 7;'#13#10'  end;'#13#10 +
      '  TOther = record B: Integer; end;'#13#10 +
      '  TExtra = record C: Integer; end;'#13#10 +
      'var'#13#10'  Item: TItem;'#13#10'  Other: TOther;'#13#10'  Extra: TExtra;';
    lGlobal := 'var A: Integer; Count: Integer;';
    lBody := 'with Item do A := Count;';
    if lShape = 'nested-forward-ancestor' then
      lBody := 'with Item do begin Writeln(Count); with Other do A := B; end;';
    if lShape = 'partial-cascade-forward-ancestor' then
    begin
      lType := 'uses System.SysUtils;'#13#10 + lType;
      lBody := 'with Item do begin A := Count; with Other do B := Count; ' +
        'try A := 6; except on Exception do with Extra do C := 1; end; end;';
    end;
  end;
  if lShape = 'tag-only' then
  begin
    // Header-on-type-line inventory cannot hide a lost tag-only model array.
    lType := 'type TRec = record A: Integer; case Count: Integer of 0: (X: Integer); end;' +
      #13#10'var Rec: TRec;';
    lGlobal := 'var Count: Integer;';
    lExpected := '.A := lWithRecPtr^.Count;';
  end;
  if lShape = 'record-constant' then
  begin
    lType := 'type TRec = record var A: Integer; const Count = 5; end;'#13#10'var Rec: TRec;';
    lGlobal := 'var Count: Integer;';
    lExpected := '.A := lWithRecPtr^.Count;';
  end;
  if MatchText(lShape, ['anonymous-include', 'anonymous-include-paren']) then
  begin
    lType := 'var'#13#10'  Rec: record'#13#10'    A: Integer;'#13#10 +
      '    {$I tag.inc}'#13#10'      0: (X: Integer);'#13#10'  end;';
    lGlobal := 'var Count: Integer;';
    if lShape = 'anonymous-include-paren' then
      lType := lType.Replace('{$I tag.inc}', '(*$I tag.inc*)');
    TFile.WriteAllText(TPath.Combine(lRoot, 'tag.inc'),
      'case Count: Integer of', TEncoding.ASCII);
  end;
  if MatchText(lShape, ['anonymous-declaration-include',
    'anonymous-declaration-include-multiline']) then
  begin
    lType := 'var {$I recvar.inc}';
    lGlobal := 'var Count: Integer;';
    TFile.WriteAllText(TPath.Combine(lRoot, 'recvar.inc'),
      'Rec: record'#13#10' A: Integer;'#13#10' case Count: Integer of'#13#10 +
      ' 0: (X: Integer);'#13#10' end;', TEncoding.ASCII);
    if lShape = 'anonymous-declaration-include-multiline' then
      TFile.WriteAllText(TPath.Combine(lRoot, 'recvar.inc'),
        'Dummy1: Integer;'#13#10'Dummy2: Integer;'#13#10 +
        TFile.ReadAllText(TPath.Combine(lRoot, 'recvar.inc'), TEncoding.ASCII),
        TEncoding.ASCII);
  end;
  if lShape = 'anonymous-type-include' then
  begin
    lType := 'var'#13#10'  Rec: {$I rectype.inc}';
    lGlobal := 'var Count: Integer;';
    TFile.WriteAllText(TPath.Combine(lRoot, 'rectype.inc'),
      'record'#13#10'    A: Integer;'#13#10'    case Count: Integer of'#13#10 +
      '      0: (X: Integer);'#13#10'  end;',
      TEncoding.ASCII);
  end;
  if lShape = 'anonymous-include-fields-only' then
  begin
    lType := 'var'#13#10'  Rec: record'#13#10'    A: Integer;'#13#10 +
      '    {$I tag.inc}'#13#10'    0: (X: Integer);'#13#10'  end;';
    lBody := 'with Rec do A := 1;';
    lExpected := 'Rec.A := 1;';
    TFile.WriteAllText(TPath.Combine(lRoot, 'tag.inc'),
      'case Count: Integer of', TEncoding.ASCII);
  end;
  if lShape = 'anonymous-inactive' then
  begin
    lType := 'var Rec: record'#13#10'    A: Integer;'#13#10 +
      '    {$IFDEF NEVER_DS731}'#13#10'    case Count: Integer of'#13#10 +
      '    {$ELSE}'#13#10'    case RealTag: Integer of'#13#10 +
      '    {$ENDIF}'#13#10'      0: (X: Integer);'#13#10'  end;';
    lGlobal := 'var Count: Integer;';
    lExpected := 'Rec.A := Count;';
  end;
  if StartsText('inline-active-', aShape) then
  begin
    lType := 'var Rec: record'#13#10'    A: Integer;'#13#10 +
      '    case {$IFDEF NEVER_DS731}RealTag{$ELSE}Count{$ENDIF}: Integer of'#13#10 +
      '      0: (X: Integer);'#13#10'  end;';
    lGlobal := 'var Count: Integer;';
  end;
  if StartsText('inactive-include-', aShape) then
  begin
    lType := 'var Rec: record'#13#10'    A: Integer;'#13#10 +
      '    {$IFDEF NEVER_DS731}'#13#10'    {$I missing.inc}'#13#10 +
      '    {$ENDIF}'#13#10'    case RealTag: Integer of'#13#10 +
      '      0: (X: Integer);'#13#10'  end;';
    lGlobal := 'var Count: Integer;';
    lExpected := 'Rec.A := Count;';
  end;
  if MatchText(lShape, ['class-var', 'instance-field']) then
  begin
    lType := 'type'#13#10'  TFoo = class'#13#10;
    if lShape = 'class-var' then
      lType := lType + '    class var CRec: record'#13#10
    else
      lType := lType + '    FRec: record'#13#10;
    lType := lType + '      A: Integer;'#13#10 +
      '      case Count: Integer of'#13#10'        0: (X: Integer);'#13#10 +
      '    end;'#13#10'    class procedure Go;'#13#10'  end;';
    lGlobal := 'var Count: Integer;';
    if lShape = 'class-var' then
      lImplementation := 'class procedure TFoo.Go;'#13#10 +
        'begin with CRec do A := Count; end;'#13#10
    else begin
      lType := lType.Replace('class procedure Go;', 'procedure Go;');
      lImplementation := 'procedure TFoo.Go;'#13#10 +
        'begin with FRec do A := Count; end;'#13#10;
      lExpected := ' FRec.A := FRec.Count;';
    end;
    lBody := '';
  end;
  if MatchText(lShape, ['helper-unrelated', 'helper-own']) then
  begin
    lType := 'type'#13#10'  TRec = record'#13#10'    Other: Integer;'#13#10;
    if lShape = 'helper-own' then
      lType := lType + '    const Count = 7;'#13#10;
    lType := lType + '  end;'#13#10 +
      '  TRecHelper = record helper for TRec'#13#10 +
      '    function Count: Integer;'#13#10'  end;'#13#10 +
      '  TFoo = record'#13#10'    const Count = 1;'#13#10'  end;'#13#10 +
      'var'#13#10'  Rec: TRec;';
    lImplementation := 'function TRecHelper.Count: Integer;'#13#10 +
      'begin Result := 4; end;'#13#10;
    lBody := 'with Rec do Other := Count;';
    lExpected := 'lWithRecPtr^.Other := lWithRecPtr^.Count;';
  end;
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P; uses Unit1, ControlUnit; begin end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dproj'),
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="Unit1.pas"/>' +
    '<DCCReference Include="ControlUnit.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  lSource := 'unit Unit1;'#13#10'interface'#13#10 + lType + #13#10 + lGlobal +
    #13#10'implementation'#13#10 + lImplementation + 'procedure Run;'#13#10 + lLocal +
    #13#10'begin'#13#10'  ' + lBody + #13#10'end;'#13#10'end.'#13#10;
  if aShape = 'rmpv-compiling-anon-field' then
  begin
    lSource := lSource.Replace('interface'#13#10, 'interface'#13#10'procedure Run;'#13#10);
    TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
      'program P; {$APPTYPE CONSOLE} uses Unit1, ControlUnit; begin Unit1.Run; end.', TEncoding.ASCII);
  end;
  if EndsText('-lf', aShape) then
    lSource := lSource.Replace(#13#10, #10);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'), lSource, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'ControlUnit.pas'),
    'unit ControlUnit;'#13#10'interface'#13#10 +
    'type TControl = record Value: Integer; const Count = 7; end;'#13#10'var Item: TControl;'#13#10 +
    'implementation'#13#10'procedure Run; begin with Item do Value := 1; end;'#13#10'end.'#13#10,
    TEncoding.ASCII);
  if StartsText('homonym-', lShape) then
    TFile.WriteAllText(TPath.Combine(lRoot, 'ControlUnit.pas'),
      TFile.ReadAllText(TPath.Combine(lRoot, 'ControlUnit.pas'), TEncoding.ASCII).Replace(
        'type TControl =', 'type TItem = record B: Integer; end;'#13#10'TControl ='), TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.Combine(lRoot, 'P.dproj');
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win64';
  lOptions.DelphiVersion := '23.0';
  lOptions.Cache.SqliteCacheFileName := TPath.Combine(lRoot, 'cache.sqlite');
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  Assert.AreEqual(Int64(0), lFacts.Metrics.SemanticCacheHits, 'Fresh SQLite file must be cold.');
  if aMode = 'warm' then
  begin
    lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
    Assert.IsTrue(lFacts.Metrics.SemanticCacheHits > 0, 'Warm SQLite facts must hit.');
  end;
  if StartsText('homonym-', lShape) then
    Assert.IsTrue(lFacts.LookupIndex.UnverifiedValueMemberMayApply('TItem', 'Count'),
      'An ambiguous simple name without verified receiver identity cannot prove coverage.');
  lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
  lSnapshotPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWithCompatibilitySnapshot(lFacts);
  if (aMode = 'standalone') or StartsText('corrupt-', aMode) then
  begin
    lIdentity := Default(TDelphiSemanticSnapshotCacheIdentity);
    lIdentity.CacheKey := 'standalone-value-proof';
    lIdentity.IdentityKey := lIdentity.CacheKey;
    lIdentity.SourceFileName := lOptions.ProjectFileName;
    lIdentity.FileHash := lFacts.ContextFingerprint;
    lIdentity.ContextHash := lFacts.ContextFingerprint;
    lIdentity.IncludeGraphHash := 'no-include-changes';
    lIdentity.SchemaVersion := 'remove-with-facts-v63';
    lStored := BuildCompatibilityRemoveWithPlanningSnapshotFromFacts(lFacts);
    try
      lCache := TDelphiSemanticSnapshotSqliteCache.Create(TPath.Combine(lRoot, 'standalone.sqlite'));
      try
        lCache.StoreProjectRemoveWithPlanningFacts(lIdentity, lStored, lFacts.Symbols);
      finally
        lCache.Free;
      end;
    finally
      lStored.Free;
    end;
    if StartsText('corrupt-', aMode) then
      CorruptStandaloneValueEvidence(TPath.Combine(lRoot, 'standalone.sqlite'),
        Copy(aMode, Length('corrupt-') + 1, MaxInt));
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(TPath.Combine(lRoot, 'standalone.sqlite'));
    try
      if StartsText('corrupt-', aMode) then
      begin
        try
          Assert.IsFalse(lCache.TryLoadProjectRemoveWithPlanningFacts(lIdentity, lLoaded),
            'Missing, partial or foreign evidence must invalidate the project cache.');
          Assert.IsTrue(lLoaded = nil);
          Assert.AreEqual(1, lCache.Metrics.Invalidations);
        finally
          lLoaded.Free;
        end;
        Exit;
      end;
      Assert.IsTrue(lCache.TryLoadProjectRemoveWithPlanningFacts(lIdentity, lLoaded));
      try
        AssertValueEvidenceEqual(lFacts.LookupIndex.ExportValueMemberEvidence,
          lLoaded.RemoveWithPlanningFacts.LookupIndex.ExportValueMemberEvidence,
          lFacts.LookupIndex, lLoaded.RemoveWithPlanningFacts.LookupIndex);
        Assert.AreEqual(Integer(Length(lFacts.UnitModels)), Integer(lLoaded.UnitCount));
        for var i := 0 to High(lFacts.UnitModels) do
        begin
          Assert.AreEqual(lFacts.UnitModels[i].SourceText,
            lLoaded.ExactTextOf(lLoaded.UnitByIndex(i).SourceTextId));
          Assert.AreEqual(lFacts.UnitModels[i].VerifiedActiveSourceText,
            lLoaded.ExactTextOf(lLoaded.UnitByIndex(i).VerifiedActiveSourceTextId));
        end;
        lSnapshotPlan := TDelphiSemanticRemoveWithPlanner.Plan(lLoaded);
      finally
        lLoaded.Free;
      end;
    finally
      lCache.Free;
    end;
  end;

  if MatchText(aMode, ['sessioncold', 'sessionwarm']) then
  begin
    for var i := 0 to Ord(aMode = 'sessionwarm') do
    begin
      lSession := TDelphiSemanticProjectSession.Open(ProjectOptionsFromApiOptions(lOptions));
      try
        Assert.IsTrue(lSession.Success);
        lSessionBuild := lSession.Session.PlanRemoveWithResult;
        Assert.AreEqual(i, Integer(lSessionBuild.SnapshotMetrics.SnapshotCacheHits));
        lSnapshotPlan := lSessionBuild.Plan;
      finally
        lSession.Session.Free;
      end;
    end;
  end;

  Assert.AreEqual(Length(lPlan.FinalStatements), Length(lSnapshotPlan.FinalStatements));
  if EndsText('-forward-ancestor', lShape) or (aShape = 'rmpv-compiling-anon-field') then
  begin
    lExpectedStatements := 1;
    if lShape = 'nested-forward-ancestor' then
      lExpectedStatements := 2
    else if lShape = 'partial-cascade-forward-ancestor' then
      lExpectedStatements := 3;
    Assert.AreEqual(lExpectedStatements + 1, Integer(Length(lPlan.FinalStatements)), lShape);
    lMatchedStatements := 0;
    for var lBinding in lFacts.Bindings do
      if SameText(ExtractFileName(lBinding.FileName), 'Unit1.pas') then
      begin
        Inc(lMatchedStatements);
        lMatches := 0;
        for lStatement in lPlan.FinalStatements do
          if lStatement.SemanticId = lBinding.SemanticId then
          begin
            Inc(lMatches);
            Assert.AreEqual(lBinding.FileName, lStatement.FileName);
            Assert.AreEqual(lBinding.Line, lStatement.Range.StartLine);
            Assert.AreEqual(lBinding.Column, lStatement.Range.StartColumn);
          end;
        Assert.AreEqual(1, lMatches, 'Every expected WITH identity must survive planning.');
      end;
    Assert.AreEqual(lExpectedStatements, lMatchedStatements, lShape);
  end else
    Assert.AreEqual(2, Integer(Length(lPlan.FinalStatements)), lShape);
  for var i := 0 to High(lPlan.FinalStatements) do
  begin
    Assert.AreEqual(lPlan.FinalStatements[i].Status, lSnapshotPlan.FinalStatements[i].Status);
    Assert.AreEqual(lPlan.FinalStatements[i].Reason, lSnapshotPlan.FinalStatements[i].Reason);
    Assert.AreEqual(lPlan.FinalStatements[i].SafetyReason, lSnapshotPlan.FinalStatements[i].SafetyReason);
    Assert.AreEqual(lPlan.FinalStatements[i].ReplacementText, lSnapshotPlan.FinalStatements[i].ReplacementText);
    Assert.AreEqual(Length(lPlan.FinalStatements[i].Edits), Length(lSnapshotPlan.FinalStatements[i].Edits));
  end;
  if MatchText(aMode, ['snapshot', 'standalone', 'sessioncold', 'sessionwarm']) then
    lPlan := lSnapshotPlan;
  for lStatement in lPlan.FinalStatements do
    if SameText(ExtractFileName(lStatement.FileName), 'Unit1.pas') then
    begin
      if MatchText(lShape, ['class-tobject', 'class-interfaced', 'class-component',
        'class-forward', 'partial-root-object', 'partial-root-interfaced', 'partial-root-component']) then
      begin
        Assert.AreEqual('skipped', lStatement.Status, aShape);
        Assert.AreEqual('receiver-member-not-found', lStatement.Reason, aShape);
        Assert.AreEqual('OWNER_INHERITED_MEMBERS_UNVERIFIED', lStatement.SafetyReason, aShape);
        Assert.AreEqual('', lStatement.ReplacementText, aShape);
        Assert.AreEqual(0, Integer(Length(lStatement.Edits)), aShape);
        Assert.AreEqual(0, Integer(Length(lStatement.Temps)), aShape);
        for var lEdit in lPlan.Edits do
          Assert.AreNotEqual(lStatement.SemanticId, lEdit.StatementId, aShape);
        Continue;
      end;
      if DS741ExpectedReplacement(lShape) <> '' then
      begin
        Assert.AreEqual('planned', lStatement.Status, lShape + ': ' + lStatement.Reason);
        Assert.AreEqual(DS741ExpectedReplacement(lShape), lStatement.ReplacementText);
        Continue;
      end else if EndsText('-forward-ancestor', lShape) or
        (aShape = 'rmpv-compiling-anon-field') then
      begin
        Assert.AreEqual('skipped', lStatement.Status, lShape + ': ' + lStatement.Reason);
        if lShape = 'nested-forward-ancestor' then
          Assert.AreEqual('OWNER_INHERITED_MEMBERS_UNVERIFIED', lStatement.SafetyReason)
        else
          Assert.AreEqual('RECEIVER_MEMBERS_PARTIALLY_VERIFIED', lStatement.SafetyReason);
        Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
        Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
        Assert.AreEqual('', lStatement.ReplacementText);
        for var lEdit in lPlan.Edits do
          Assert.AreNotEqual(lStatement.SemanticId, lEdit.StatementId);
        Continue;
      end else if StartsText('nested-', lShape) and (not EndsText('-control', lShape)) then
      begin
        Assert.AreEqual('skipped', lStatement.Status, lShape + ': ' + lStatement.Reason);
        Assert.AreEqual('RECEIVER_MEMBERS_PARTIALLY_VERIFIED', lStatement.SafetyReason);
        Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
        Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
        Assert.AreEqual('', lStatement.ReplacementText);
        for var lEdit in lPlan.Edits do
          Assert.AreNotEqual(lStatement.SemanticId, lEdit.StatementId,
            'Refusal removes outer and dependent nested candidate edits.');
        Continue;
      end;
      if lShape = 'anon-pointer-control' then
      begin
        Assert.AreEqual('skipped', lStatement.Status);
        Assert.AreEqual('scope-unverified', lStatement.Reason);
        Assert.AreEqual('SCOPE_UNVERIFIED', lStatement.SafetyReason);
        Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
        Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
        Assert.AreEqual('', lStatement.ReplacementText);
        Continue;
      end;
      if MatchText(lShape, ['anonymous-global', 'anonymous-local', 'anonymous-include', 'helper-own',
        'anonymous-declaration-include', 'anonymous-declaration-include-multiline',
        'anonymous-type-include', 'anonymous-include-paren', 'class-var',
        'indexed-named-tag', 'indexed-inline-tag', 'strong-alias-qualified-target',
        'receiver-diagnostic', 'homonym-unverified', 'partial-weak-global',
        'partial-weak-noglobal', 'partial-strong-global', 'partial-indexed-ancestor',
        'anon-partial-field', 'anon-partial-enum', 'anon-partial-include', 'anon-pointer-control']) or
        StartsText('inline-active-', aShape) then
      begin
        Assert.AreEqual('skipped', lStatement.Status, aShape);
        if MatchText(lShape, ['anon-partial-field', 'anon-partial-enum']) then
          Assert.AreEqual('RECEIVER_MEMBERS_PARTIALLY_VERIFIED', lStatement.Reason)
        else if lShape = 'partial-strong-global' then
          Assert.AreEqual('TYPE_VALUE_MEMBERS_UNVERIFIED', lStatement.Reason)
        else if StartsText('partial-', lShape) then
          Assert.AreEqual('RECEIVER_MEMBERS_PARTIALLY_VERIFIED', lStatement.Reason)
        else if lShape = 'homonym-unverified' then
          Assert.AreEqual('receiver-type-not-visible', lStatement.Reason)
        else if lShape = 'receiver-diagnostic' then
          Assert.AreEqual('members-incomplete', lStatement.Reason)
        else if lShape = 'helper-own' then
          Assert.AreEqual('symbol-not-found', lStatement.Reason)
        else
          Assert.AreEqual('TYPE_VALUE_MEMBERS_UNVERIFIED', lStatement.Reason);
        if MatchText(lShape, ['anon-partial-field', 'anon-partial-enum']) then
          Assert.AreEqual('RECEIVER_MEMBERS_PARTIALLY_VERIFIED', lStatement.SafetyReason)
        else if lShape = 'partial-strong-global' then
          Assert.AreEqual('TYPE_VALUE_MEMBERS_UNVERIFIED', lStatement.SafetyReason)
        else if StartsText('partial-', lShape) then
          Assert.AreEqual('RECEIVER_MEMBERS_PARTIALLY_VERIFIED', lStatement.SafetyReason)
        else if lShape = 'homonym-unverified' then
          Assert.AreEqual('receiver-type-not-visible', lStatement.SafetyReason)
        else if lShape = 'receiver-diagnostic' then
          Assert.AreEqual('MEMBERS_INCOMPLETE', lStatement.SafetyReason)
        else
          Assert.AreEqual('TYPE_VALUE_MEMBERS_UNVERIFIED', lStatement.SafetyReason);
        Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
        Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
        Assert.AreEqual('', lStatement.ReplacementText);
        // The unverified control stops before the value barrier's candidate filter.
        if lShape <> 'homonym-unverified' then
          for var lEdit in lPlan.Edits do
            Assert.AreNotEqual(lStatement.SemanticId, lEdit.StatementId, 'Refusal removes its candidate.');
      end else begin
        Assert.AreEqual('planned', lStatement.Status, aShape + ': ' + lStatement.Reason);
        Assert.IsTrue(ContainsText(lStatement.ReplacementText, lExpected), lStatement.ReplacementText);
        if MatchText(lShape, ['anonymous-control', 'num-rec', 'anonymous-inactive',
          'anonymous-include-fields-only']) or StartsText('inactive-include-', aShape) then
        begin
          Assert.AreEqual(' ' + lExpected, lStatement.ReplacementText);
          Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
          Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
        end;
      end;
    end else begin
      Assert.AreEqual('ControlUnit.pas', ExtractFileName(lStatement.FileName));
      Assert.AreEqual('planned', lStatement.Status);
      Assert.IsTrue(ContainsText(lStatement.ReplacementText, '.Value := 1;'));
    end;
end;

function TWithBinderTests.TypeValueSafetyModels(const aShape: string): TArray<TDelphiSemanticUnitModel>;
var
  lOptions: TDelphiSemanticModelOptions;
  lPath, lRoot: string;
  lModels: TList<TDelphiSemanticUnitModel>;
begin
  lRoot := WithBinderTempPath('DS731-safety-' + aShape);
  TDirectory.CreateDirectory(lRoot);
  if aShape = 'rc-sameline-peer' then
  begin
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'type'#13#10 +
      '  TRec = record'#13#10 +
      '    const CLo = 1; Count = 5;'#13#10 +
      '    var Other: Integer;'#13#10 +
      '  end;'#13#10 +
      'var Rec: TRec;'#13#10 +
      'var'#13#10 +
      '  Count: Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      '  with Rec do Other := Count;'#13#10 +
      'end;'#13#10 +
      'end.', TEncoding.ASCII);
  end;
  if aShape = 'rc-section-multiline' then
  begin
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'type'#13#10 +
      '  TRec = record'#13#10 +
      '    const'#13#10 +
      '      CLo = 1;'#13#10 +
      '      Count = 5;'#13#10 +
      '    var'#13#10 +
      '      Other: Integer;'#13#10 +
      '  end;'#13#10 +
      'var Rec: TRec;'#13#10 +
      'var'#13#10 +
      '  Count: Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      '  with Rec do Other := Count;'#13#10 +
      'end;'#13#10 +
      'end.', TEncoding.ASCII);
  end;
  if aShape = 'rc-imported-recv' then
  begin
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses Unit2;'#13#10 +
      'var Rec: TRec;'#13#10 +
      'var'#13#10 +
      '  Count: Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      '  with Rec do Other := Count;'#13#10 +
      'end;'#13#10 +
      'end.', TEncoding.ASCII);
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit2.pas'),
      'unit Unit2;'#13#10 +
      'interface'#13#10 +
      'type'#13#10 +
      '  TRec = record'#13#10 +
      '    const Count = 5;'#13#10 +
      '    var Other: Integer;'#13#10 +
      '  end;'#13#10 +
      'implementation'#13#10 +
      ''#13#10 +
      'end.', TEncoding.ASCII);
  end;
  if aShape = 'rc-private-same-unit' then
  begin
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'type'#13#10 +
      '  TRec = record'#13#10 +
      '  private'#13#10 +
      '    const Count = 5;'#13#10 +
      '  public'#13#10 +
      '    Other: Integer;'#13#10 +
      '  end;'#13#10 +
      'var Rec: TRec;'#13#10 +
      'var'#13#10 +
      '  Count: Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      '  with Rec do Other := Count;'#13#10 +
      'end;'#13#10 +
      'end.', TEncoding.ASCII);
  end;
  if aShape = 'vt-local-record' then
  begin
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'var'#13#10 +
      '  Count: Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      '  TLoc = record'#13#10 +
      '    Other: Integer;'#13#10 +
      '    case Count: Integer of'#13#10 +
      '      0: (A: Integer);'#13#10 +
      '  end;'#13#10 +
      'var'#13#10 +
      '  L: TLoc;'#13#10 +
      'begin'#13#10 +
      '  with L do A := Count;'#13#10 +
      'end;'#13#10 +
      'end.', TEncoding.ASCII);
  end;
  if aShape = 'cc-global-read' then
  begin
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'type'#13#10 +
      '  TC = class'#13#10 +
      '  public'#13#10 +
      '    const Count = 5;'#13#10 +
      '    var Other: Integer;'#13#10 +
      '  end;'#13#10 +
      'var Obj: TC;'#13#10 +
      'var'#13#10 +
      '  Count: Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      '  with Obj do Other := Count;'#13#10 +
      'end;'#13#10 +
      'end.', TEncoding.ASCII);
  end;
  if aShape = 'cc-inherited-import' then
  begin
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses Unit2;'#13#10 +
      'type'#13#10 +
      '  TDerived = class(TBase)'#13#10 +
      '  public'#13#10 +
      '    Other: Integer;'#13#10 +
      '  end;'#13#10 +
      'var Obj: TDerived;'#13#10 +
      'var'#13#10 +
      '  Count: Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      '  with Obj do Other := Count;'#13#10 +
      'end;'#13#10 +
      'end.', TEncoding.ASCII);
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit2.pas'),
      'unit Unit2;'#13#10 +
      'interface'#13#10 +
      'type'#13#10 +
      '  TBase = class'#13#10 +
      '  public'#13#10 +
      '    const Count = 5;'#13#10 +
      '  end;'#13#10 +
      'implementation'#13#10 +
      ''#13#10 +
      'end.', TEncoding.ASCII);
  end;
  if aShape = 'cc-derived-const' then
  begin
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'type'#13#10 +
      '  TBase = class'#13#10 +
      '  public'#13#10 +
      '    Count: Integer;'#13#10 +
      '  end;'#13#10 +
      '  TDerived = class(TBase)'#13#10 +
      '  public'#13#10 +
      '    const Count = 5;'#13#10 +
      '    var Other: Integer;'#13#10 +
      '  end;'#13#10 +
      'var Obj: TDerived;'#13#10 +
      'var'#13#10 +
      '  Count: Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      '  with Obj do Other := Count;'#13#10 +
      'end;'#13#10 +
      'end.', TEncoding.ASCII);
  end;
  if aShape = 'rc-local' then
  begin
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'type'#13#10 +
      '  TRec = record'#13#10 +
      '    const Count = 5;'#13#10 +
      '    var Other: Integer;'#13#10 +
      '  end;'#13#10 +
      'var Rec: TRec;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'var'#13#10 +
      '  Count: Integer;'#13#10 +
      'begin'#13#10 +
      '  Count := 0;'#13#10 +
      '  with Rec do Other := Count;'#13#10 +
      'end;'#13#10 +
      'end.', TEncoding.ASCII);
  end;
  if aShape = 'vt-nested-variant' then
  begin
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'type'#13#10 +
      '  TRec = record'#13#10 +
      '    case Tag: Integer of'#13#10 +
      '      0: (A: Integer; case Count: Byte of 0: (B: Byte));'#13#10 +
      '  end;'#13#10 +
      'var Rec: TRec;'#13#10 +
      'var'#13#10 +
      '  Count: Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      '  with Rec do A := Count;'#13#10 +
      'end;'#13#10 +
      'end.', TEncoding.ASCII);
  end;
  if aShape = 'cc-private-import' then
  begin
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses Unit2;'#13#10 +
      'var Obj: TC;'#13#10 +
      'var'#13#10 +
      '  Count: Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      '  with Obj do Other := Count;'#13#10 +
      'end;'#13#10 +
      'end.', TEncoding.ASCII);
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit2.pas'),
      'unit Unit2;'#13#10 +
      'interface'#13#10 +
      'type'#13#10 +
      '  TC = class'#13#10 +
      '  private'#13#10 +
      '    const Count = 5;'#13#10 +
      '  public'#13#10 +
      '    Other: Integer;'#13#10 +
      '  end;'#13#10 +
      'implementation'#13#10 +
      ''#13#10 +
      'end.', TEncoding.ASCII);
  end;
  if aShape = 'cc-strict-private-same-unit' then
  begin
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'type'#13#10 +
      '  TC = class'#13#10 +
      '  strict private'#13#10 +
      '    const Count = 5;'#13#10 +
      '  public'#13#10 +
      '    Other: Integer;'#13#10 +
      '  end;'#13#10 +
      'var Obj: TC;'#13#10 +
      'var'#13#10 +
      '  Count: Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      '  with Obj do Other := Count;'#13#10 +
      'end;'#13#10 +
      'end.', TEncoding.ASCII);
  end;
  if aShape = 'cc-protected-descendant' then
  begin
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses Unit2;'#13#10 +
      'type'#13#10 +
      '  TD = class(TC)'#13#10 +
      '  public'#13#10 +
      '    procedure Run;'#13#10 +
      '  end;'#13#10 +
      'var'#13#10 +
      '  Count: Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure TD.Run;'#13#10 +
      'var'#13#10 +
      '  Obj: TC;'#13#10 +
      'begin'#13#10 +
      '  Obj := nil;'#13#10 +
      '  with Obj do Other := Count;'#13#10 +
      'end;'#13#10 +
      'end.', TEncoding.ASCII);
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit2.pas'),
      'unit Unit2;'#13#10 +
      'interface'#13#10 +
      'type'#13#10 +
      '  TC = class'#13#10 +
      '  protected'#13#10 +
      '    const Count = 5;'#13#10 +
      '  public'#13#10 +
      '    Other: Integer;'#13#10 +
      '  end;'#13#10 +
      'implementation'#13#10 +
      ''#13#10 +
      'end.', TEncoding.ASCII);
  end;
  if aShape = 'rc-helper-const' then
  begin
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'type'#13#10 +
      '  TRec = record'#13#10 +
      '    Other: Integer;'#13#10 +
      '  end;'#13#10 +
      '  TRecHelper = record helper for TRec'#13#10 +
      '    const Count = 5;'#13#10 +
      '  end;'#13#10 +
      'var Rec: TRec;'#13#10 +
      'var'#13#10 +
      '  Count: Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      '  with Rec do Other := Count;'#13#10 +
      'end;'#13#10 +
      'end.', TEncoding.ASCII);
  end;
  if aShape = 'lost-constant' then
  begin
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'type'#13#10 +
      '  TRec = record'#13#10 +
      '    const Count = 5;'#13#10 +
      '    var Other: Integer;'#13#10 +
      '  end;'#13#10 +
      'var Rec: TRec;'#13#10 +
      'var'#13#10 +
      '  Count: Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      '  with Rec do Other := Count;'#13#10 +
      'end;'#13#10 +
      'end.', TEncoding.ASCII);
  end;
  if aShape = 'rc-unit-const-ctl' then
  begin
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'type'#13#10 +
      '  TRec = record'#13#10 +
      '    Other: Integer;'#13#10 +
      '  end;'#13#10 +
      'const'#13#10 +
      '  Count = 5;'#13#10 +
      'var Rec: TRec;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      '  with Rec do Other := Count;'#13#10 +
      'end;'#13#10 +
      'end.', TEncoding.ASCII);
  end;
  if aShape = 'rc-foreign-homonym' then
  begin
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses Unit2;'#13#10 +
      'type'#13#10 +
      '  TRec = record'#13#10 +
      '    Other: Integer;'#13#10 +
      '  end;'#13#10 +
      'var Rec: TRec;'#13#10 +
      'var'#13#10 +
      '  Count: Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      '  with Rec do Other := Count;'#13#10 +
      'end;'#13#10 +
      'end.', TEncoding.ASCII);
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit2.pas'),
      'unit Unit2;'#13#10 +
      'interface'#13#10 +
      'type'#13#10 +
      '  TRec = record'#13#10 +
      '    const Count = 5;'#13#10 +
      '    var Other: Integer;'#13#10 +
      '  end;'#13#10 +
      'implementation'#13#10 +
      ''#13#10 +
      'end.', TEncoding.ASCII);
  end;
  if aShape = 'rc-nested-type-neg' then
  begin
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'type'#13#10 +
      '  TRec = record'#13#10 +
      '    type TInner = record'#13#10 +
      '      const Count = 5;'#13#10 +
      '    end;'#13#10 +
      '    var Other: Integer;'#13#10 +
      '  end;'#13#10 +
      'var Rec: TRec;'#13#10 +
      'var'#13#10 +
      '  Count: Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      '  with Rec do Other := Count;'#13#10 +
      'end;'#13#10 +
      'end.', TEncoding.ASCII);
  end;
  if aShape = 'vt-inline-field-neg' then
  begin
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'type'#13#10 +
      '  TRec = record'#13#10 +
      '    Data: record'#13#10 +
      '      case Count: Integer of'#13#10 +
      '        0: (A: Integer);'#13#10 +
      '    end;'#13#10 +
      '    Other: Integer;'#13#10 +
      '  end;'#13#10 +
      'var Rec: TRec;'#13#10 +
      'var'#13#10 +
      '  Count: Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      '  with Rec do Other := Count;'#13#10 +
      'end;'#13#10 +
      'end.', TEncoding.ASCII);
  end;
  if aShape = 'cc-derived-field-hides' then
  begin
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'type'#13#10 +
      '  TBase = class'#13#10 +
      '  public'#13#10 +
      '    const Count = 5;'#13#10 +
      '  end;'#13#10 +
      '  TDerived = class(TBase)'#13#10 +
      '  public'#13#10 +
      '    Count: Integer;'#13#10 +
      '    Other: Integer;'#13#10 +
      '  end;'#13#10 +
      'var Obj: TDerived;'#13#10 +
      'var'#13#10 +
      '  Count: Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      '  with Obj do Other := Count;'#13#10 +
      'end;'#13#10 +
      'end.', TEncoding.ASCII);
  end;
  if aShape = 'rc-cond-inactive' then
  begin
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'type'#13#10 +
      '  TRec = record'#13#10 +
      '{$IFDEF DS731_NEVER_DEFINED}'#13#10 +
      '    const Count = 5;'#13#10 +
      '{$ENDIF}'#13#10 +
      '    var Other: Integer;'#13#10 +
      '  end;'#13#10 +
      'var Rec: TRec;'#13#10 +
      'var'#13#10 +
      '  Count: Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      '  with Rec do Other := Count;'#13#10 +
      'end;'#13#10 +
      'end.', TEncoding.ASCII);
  end;
  if aShape = 'vt-tagless-field' then
  begin
    TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'type'#13#10 +
      '  TRec = record'#13#10 +
      '    case Integer of'#13#10 +
      '      0: (A: Integer);'#13#10 +
      '      1: (Count: Byte);'#13#10 +
      '  end;'#13#10 +
      'var Rec: TRec;'#13#10 +
      'var'#13#10 +
      '  Count: Integer;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      '  with Rec do A := Count;'#13#10 +
      'end;'#13#10 +
      'end.', TEncoding.ASCII);
  end;
  lModels := TList<TDelphiSemanticUnitModel>.Create;
  try
    lOptions := Default(TDelphiSemanticModelOptions);
    lOptions.ProjectContextApplied := True;
    for lPath in TDirectory.GetFiles(lRoot, '*.pas') do
    begin
      lOptions.SourceFileName := lPath;
      lModels.Add(TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions));
      Assert.IsTrue(lModels.Last.Success, aShape);
      Assert.AreEqual('ast', lModels.Last.ScopeModelStatus, aShape);
    end;
    Result := lModels.ToArray;
  finally
    lModels.Free;
  end;
  if aShape = 'vt-nested-variant' then
    Assert.AreEqual(2, Integer(Length(Result[0].TypeValueMembers)),
      'Both tags are extracted even when ordinary field B is incomplete.');
  if aShape = 'lost-constant' then
    Result[0].TypeValueMembers := nil;
end;

procedure TWithBinderTests.TypeValueSafetyAndSnapshot(const aShape: string);
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lPlan, lSnapshotPlan: TDelphiSemanticRemoveWithPlan;
  lReference: TDelphiSemanticBoundReference;
  lFound: Boolean;
  lExpectedKind, lExpectedCode: string;
begin
  lFacts := TDelphiSemanticWithBinder.BindProject('ds731-safety-' + aShape, nil,
    TypeValueSafetyModels(aShape));
  lFound := False;
  lExpectedKind := 'const';
  if StartsText('vt-', aShape) then
    lExpectedKind := 'variant-tag';
  lExpectedCode := '';
  if MatchText(aShape, ['cc-private-import', 'cc-strict-private-same-unit',
    'cc-protected-descendant']) then
    lExpectedCode := 'TYPE_VALUE_MEMBER_ACCESS_UNVERIFIED';
  if MatchText(aShape, ['rc-helper-const', 'lost-constant']) then
    lExpectedCode := 'TYPE_VALUE_MEMBERS_UNVERIFIED';
  for var lBinding in lFacts.Bindings do
    for lReference in lBinding.References do
      if SameText(lReference.Name, 'Count') then
      begin
        lFound := True;
        if aShape = 'vt-nested-variant' then
        begin
          // Existing MEMBERS_INCOMPLETE for B still shields receiver lookup.
          Assert.AreEqual('unsupported', lReference.Classification, aShape);
          Assert.AreEqual('OWNER_INHERITED_MEMBERS_UNVERIFIED', lReference.ReasonCode);
        end else if lExpectedCode <> '' then
        begin
          Assert.AreEqual('unsupported', lReference.Classification, aShape);
          Assert.AreEqual(lExpectedCode, lReference.ReasonCode, aShape);
        end else if MatchText(aShape, ['rc-unit-const-ctl', 'rc-foreign-homonym',
          'rc-nested-type-neg', 'vt-inline-field-neg', 'rc-cond-inactive']) then
          Assert.AreNotEqual('member', lReference.Classification, aShape)
        else begin
          Assert.AreEqual('member', lReference.Classification, aShape);
          Assert.AreEqual('receiver', lReference.LookupSource, aShape);
          if MatchText(aShape, ['cc-derived-field-hides', 'vt-tagless-field']) then
            Assert.AreEqual('field', lReference.Kind, aShape)
          else
            Assert.AreEqual(lExpectedKind, lReference.Kind, aShape);
        end;
      end;
  Assert.IsTrue(lFound, 'Expected a Count reference: ' + aShape);
  lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
  lSnapshotPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWithCompatibilitySnapshot(lFacts);
  Assert.AreEqual(Length(lPlan.FinalStatements), Length(lSnapshotPlan.FinalStatements));
  for var i := 0 to High(lPlan.FinalStatements) do
  begin
    Assert.AreEqual(lPlan.FinalStatements[i].Status, lSnapshotPlan.FinalStatements[i].Status, aShape);
    Assert.AreEqual(lPlan.FinalStatements[i].Reason, lSnapshotPlan.FinalStatements[i].Reason, aShape);
    Assert.AreEqual(lPlan.FinalStatements[i].SafetyReason, lSnapshotPlan.FinalStatements[i].SafetyReason, aShape);
    Assert.AreEqual(lPlan.FinalStatements[i].ReplacementText, lSnapshotPlan.FinalStatements[i].ReplacementText, aShape);
    if lExpectedCode <> '' then
    begin
      Assert.AreEqual('skipped', lPlan.FinalStatements[i].Status, aShape);
      Assert.AreEqual('TYPE_VALUE_MEMBERS_UNVERIFIED', lPlan.FinalStatements[i].SafetyReason, aShape);
      Assert.AreEqual(0, Integer(Length(lPlan.FinalStatements[i].Temps)));
      Assert.AreEqual(0, Integer(Length(lPlan.FinalStatements[i].Edits)));
      Assert.AreEqual('', lPlan.FinalStatements[i].ReplacementText);
      for var lEdit in lPlan.Edits do
        Assert.AreNotEqual(lPlan.FinalStatements[i].SemanticId, lEdit.StatementId);
    end;
  end;
end;

procedure TWithBinderTests.AliasFieldUsesDeclaredReceiverIdentity(const aCase: string);
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lPlan, lSnapshotPlan: TDelphiSemanticRemoveWithPlan;
begin
  lPath := WithBinderTempPath('ds741-owner-' + aCase + '.pas');
  TFile.WriteAllText(lPath,
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'type'#13#10 +
      '  TOuter = record'#13#10 +
      '    A: Integer;'#13#10 +
      '  end;'#13#10 +
      '  TInner = record'#13#10 +
      '    var A: Integer;'#13#10 +
      '  end;'#13#10 +
      '  TAlias = TInner;'#13#10 +
      'var'#13#10 +
      '  Outer: TOuter;'#13#10 +
      '  Item: TAlias;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      '  with Outer, Item do A := 7;'#13#10 +
      'end;'#13#10 +
      'end.'#13#10, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  SetLength(lModels, 1);
  lModels[0] := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModels[0].Success);
  lFacts := TDelphiSemanticWithBinder.BindProject('ds741-owner-' + aCase, nil, lModels);
  Assert.AreEqual(1, Integer(Length(lFacts.Bindings)));
  Assert.IsTrue(HasReference(lFacts.Bindings[0], 'A', 'member'));
  // Hand-built target decision isolates owner matching from the pre-existing
  // multi-selector alias-shape guard. The binder alias route is tested separately.
  lFacts.Bindings[0].Selectors[1].TypeName := 'TInner';
  for var lSymbol in lFacts.Symbols do
    if (lSymbol.Name = 'A') and (lSymbol.OwnerName = 'TInner') and
      (lSymbol.OwnerIdentity.DeclaredId.Value <> '') then
      lFacts.Bindings[0].Selectors[1].TypeIdentity := lSymbol.OwnerIdentity;
  if aCase = 'foreign' then
  begin
    // A hand-built binder reference whose declaring owner is in no selected lineage.
    for var i := 0 to High(lFacts.Bindings[0].References) do
      if lFacts.Bindings[0].References[i].Name = 'A' then
      begin
        lFacts.Bindings[0].References[i].Classification := 'member';
        lFacts.Bindings[0].References[i].LookupSource := 'receiver';
        lFacts.Bindings[0].References[i].ReceiverTypeName := 'UnselectedReceiver';
      end;
    for var i := 0 to High(lFacts.Symbols) do
      if lFacts.Symbols[i].Name = 'A' then
      begin
        lFacts.Symbols[i].OwnerName := 'UnselectedReceiver';
        lFacts.Symbols[i].OwnerType := 'UnselectedReceiver';
        lFacts.Symbols[i].SourceOwnerType := 'UnselectedReceiver';
      end;
    lFacts.LookupIndex := TDelphiSemanticRemoveWithLookupIndex.Build(nil, lFacts.Symbols);
  end;
  lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
  lSnapshotPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWithCompatibilitySnapshot(lFacts);
  Assert.AreEqual(1, Integer(Length(lPlan.FinalStatements)));
  Assert.AreEqual(lPlan.FinalStatements[0].Status, lSnapshotPlan.FinalStatements[0].Status);
  Assert.AreEqual(lPlan.FinalStatements[0].ReplacementText, lSnapshotPlan.FinalStatements[0].ReplacementText);
  if aCase = 'homonym' then
  begin
    Assert.AreEqual('TInner', ReceiverOf(lFacts.Bindings[0], 'A', 'member'));
    Assert.AreEqual('planned', lPlan.FinalStatements[0].Status, lPlan.FinalStatements[0].Reason);
    Assert.AreEqual('  lWithOuterPtr := @Outer;'#13#10 +
      '  lWithInnerPtr := @Item;'#13#10 +
      ' lWithInnerPtr^.A := 7;', lPlan.FinalStatements[0].ReplacementText);
  end else begin
    Assert.AreEqual('skipped', lPlan.FinalStatements[0].Status);
    Assert.AreEqual('receiver-member-unqualified', lPlan.FinalStatements[0].Reason);
    Assert.AreEqual(lPlan.FinalStatements[0].Reason, lSnapshotPlan.FinalStatements[0].Reason);
    Assert.AreEqual('', lPlan.FinalStatements[0].ReplacementText);
    Assert.AreEqual(0, Integer(Length(lPlan.FinalStatements[0].Temps)));
    Assert.AreEqual(0, Integer(Length(lPlan.FinalStatements[0].Edits)));
    Assert.AreEqual(0, Integer(Length(lPlan.Edits)));
  end;
end;

procedure TWithBinderTests.ValueMemberWithoutReceiverMatchRemovesCandidate;
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lPlan, lSnapshotPlan: TDelphiSemanticRemoveWithPlan;
  lFound: Boolean;
begin
  lFacts := TDelphiSemanticWithBinder.BindProject('ds731-no-receiver-match', nil,
    TypeValueMemberModels('rc-global-read'));
  lFound := False;
  for var i := 0 to High(lFacts.Bindings[0].References) do
    if SameText(lFacts.Bindings[0].References[i].Name, 'Count') then
    begin
      lFound := True;
      Assert.AreEqual('member', lFacts.Bindings[0].References[i].Classification);
      lFacts.Bindings[0].References[i].ReceiverTypeName := 'UnselectedReceiver';
    end;
  Assert.IsTrue(lFound);
  lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
  lSnapshotPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWithCompatibilitySnapshot(lFacts);
  Assert.AreEqual(1, Integer(Length(lPlan.FinalStatements)));
  Assert.AreEqual('skipped', lPlan.FinalStatements[0].Status);
  Assert.AreEqual('receiver-member-unqualified', lPlan.FinalStatements[0].Reason);
  Assert.AreEqual(lPlan.FinalStatements[0].Reason, lSnapshotPlan.FinalStatements[0].Reason);
  Assert.AreEqual(0, Integer(Length(lPlan.FinalStatements[0].Temps)));
  Assert.AreEqual(0, Integer(Length(lPlan.FinalStatements[0].Edits)));
  Assert.AreEqual(0, Integer(Length(lPlan.Edits)));
  Assert.AreEqual('', lPlan.FinalStatements[0].ReplacementText);
end;


procedure TWithBinderTests.ValueMemberReceiverDecisions(const aCase: string);
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lOptions: TDelphiSemanticModelOptions;
  lPath, lDistinctId: string;
  lPlan, lSnapshotPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
  lFound: Boolean;
begin
  if aCase = 'conflict' then
  begin
    lModels := TypeValueMemberModels('vt-nested-with');
    lFacts := TDelphiSemanticWithBinder.BindProject('ds731-decision-conflict', nil, lModels);
    Assert.AreEqual(2, Integer(Length(lFacts.Bindings)));
    Assert.AreNotEqual(lFacts.Bindings[0].Selectors[0].TypeIdentity.DeclaredId.Value,
      lFacts.Bindings[1].Selectors[1].TypeIdentity.DeclaredId.Value);
    // Same spelling is not authority when the selected declarations differ.
    lDistinctId := lFacts.Bindings[0].Selectors[0].TypeIdentity.DeclaredId.Value;
    lFacts.Bindings[0].Selectors[0].TypeName := 'TRec';
    lFacts.Bindings[0].Selectors[0].TypeIdentity := lFacts.Bindings[1].Selectors[1].TypeIdentity;
    lFacts.Bindings[0].Selectors[0].TypeIdentity.DeclaredId.Value := lDistinctId;
    lFacts.Bindings[1].Selectors[0] := lFacts.Bindings[0].Selectors[0];
    // Preserve source visibility coordinates to reach the decision identity gate;
    // only the competing declaration identity is deliberately foreign.

  end else begin
    lPath := WithBinderTempPath('DS731-retained.pas');
    TFile.WriteAllText(lPath, 'unit Unit1;'#13#10'interface'#13#10 +
      'type'#13#10'  TRec = record'#13#10'    const Count = 7;'#13#10'  end;'#13#10 +
      '  TInner = record'#13#10'    Other: Integer;'#13#10'  end;'#13#10 +
      'var'#13#10'  Rec: TRec;'#13#10'  Item: TInner;'#13#10 +
      'implementation'#13#10 +
      'function GetRec: TRec; begin Result := Rec; end;'#13#10 +
      'procedure Run;'#13#10'begin'#13#10 +
      '  with GetRec do'#13#10'    with Item do Other := Count;'#13#10'end;'#13#10'end.',
      TEncoding.ASCII);
    lOptions := Default(TDelphiSemanticModelOptions);
    lOptions.SourceFileName := lPath;
    lOptions.ProjectContextApplied := True;
    SetLength(lModels, 1);
    lModels[0] := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
    Assert.IsTrue(lModels[0].Success);
    lFacts := TDelphiSemanticWithBinder.BindProject('ds731-retained-member', nil, lModels);
    Assert.AreEqual(2, Integer(Length(lFacts.Bindings)));
    // A record-returning call keeps the parent WITH and its member scope.
  end;
  lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
  lSnapshotPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWithCompatibilitySnapshot(lFacts);
  Assert.AreEqual(Length(lPlan.FinalStatements), Length(lSnapshotPlan.FinalStatements));
  lFound := False;
  for var i := 0 to High(lPlan.FinalStatements) do
  begin
    lStatement := lPlan.FinalStatements[i];
    Assert.AreEqual(lStatement.Status, lSnapshotPlan.FinalStatements[i].Status);
    Assert.AreEqual(lStatement.Reason, lSnapshotPlan.FinalStatements[i].Reason);
    Assert.AreEqual(lStatement.ReplacementText, lSnapshotPlan.FinalStatements[i].ReplacementText);
    if aCase = 'conflict' then
    begin
      Assert.AreEqual('skipped', lStatement.Status);
      Assert.AreEqual('receiver-member-unqualified', lStatement.Reason);
      Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
      Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
      Assert.AreEqual('', lStatement.ReplacementText);
      Assert.AreEqual(0, Integer(Length(lPlan.Edits)));
      lFound := True;
    end else if SameText(lStatement.Status, 'planned') then
    begin
      Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
      Assert.IsTrue(ContainsText(lStatement.ReplacementText, '.Other := Count;'), lStatement.ReplacementText);
      Assert.IsFalse(ContainsText(lStatement.ReplacementText, '.Count'));
      lFound := True;
    end;
  end;
  Assert.IsTrue(lFound, aCase);
end;

procedure TWithBinderTests.RetainedSameLineParentKeepsChildScope(
  const aMember, aStrategy: string);
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lOptions: TDelphiSemanticModelOptions;
  lPath, lMember, lLocal, lChild, lSource: string;
  lPlan, lSnapshotPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
  lEdit: TDelphiSemanticRemoveWithFinalTextEdit;
  lFound: Boolean;
begin
  lPath := WithBinderTempPath('DS740-' + aMember + '-' + aStrategy + '.pas');
  lMember := 'const Count = 7;';
  if aMember = 'field' then
    lMember := 'Count: Integer;';
  lLocal := '';
  lChild := 'Item';
  if aStrategy = 'direct' then
  begin
    lLocal := 'var aItem: TInner';
    lChild := 'aItem';
  end;
  lSource := 'unit Unit1;'#13#10'interface'#13#10 +
    'type TRec = record ' + lMember + ' end;'#13#10 +
    'TInner = record Other: Integer; procedure Touch; end;'#13#10 +
    'var Item: TInner; Count: Integer;'#13#10'implementation'#13#10 +
    'function GetRec: TRec; begin Result := Default(TRec); end;'#13#10 +
    'procedure TInner.Touch; begin end;'#13#10 +
    'procedure Run(' + lLocal + ');'#13#10'begin'#13#10 +
    '  with GetRec do with ' + lChild + ' do Other := Count;'#13#10'end;'#13#10'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  SetLength(lModels, 1);
  lModels[0] := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModels[0].Success);
  lFacts := TDelphiSemanticWithBinder.BindProject('ds740-retained-parent', nil, lModels);
  Assert.AreEqual(2, Integer(Length(lFacts.Bindings)));
  Assert.IsTrue(HasReference(lFacts.Bindings[1], 'Count', 'member'));
  lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
  lSnapshotPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWithCompatibilitySnapshot(lFacts);
  Assert.AreEqual('skipped', lPlan.FinalStatements[0].Status);
  lFound := False;
  for var i := 0 to High(lPlan.FinalStatements) do
  begin
    lStatement := lPlan.FinalStatements[i];
    Assert.AreEqual(lStatement.Status, lSnapshotPlan.FinalStatements[i].Status);
    Assert.AreEqual(lStatement.ReplacementText, lSnapshotPlan.FinalStatements[i].ReplacementText);
    if not SameText(lStatement.Status, 'planned') then
      Continue;
    lFound := True;
    Assert.IsTrue(ContainsText(lStatement.ReplacementText, '.Other := Count;'));
    for lEdit in lStatement.Edits do
      if lEdit.Kind = 'replace-statement' then
      begin
        Assert.AreEqual(lFacts.Bindings[1].Column, lEdit.Range.StartColumn,
          'The child edit must not erase the retained parent header.');
        if aStrategy = 'direct' then
          Assert.AreEqual(' aItem.Other := Count;', lEdit.ReplacementText)
        else
        begin
          Assert.IsTrue(StartsText('begin' + sLineBreak, lEdit.ReplacementText));
          Assert.IsTrue(EndsText(sLineBreak + StringOfChar(' ',
            lFacts.Bindings[1].Column - 1) + 'end;', lEdit.ReplacementText),
            'The entire replacement must be one complete BEGIN/END statement.');
        end;
      end;
  end;
  Assert.IsTrue(lFound, 'An exactly separable child should remain planned.');
end;

procedure TWithBinderTests.PrefixedWithKeepsControlledStatement(const aCase: string);
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lOptions: TDelphiSemanticModelOptions;
  lPath, lBody, lSource, lExpectedEnd: string;
  lPlan, lSnapshotPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
  lEdit: TDelphiSemanticRemoveWithFinalTextEdit;
  lFound: Boolean;
begin
  lBody := '';
  if aCase = 'split-do' then
    lBody := '  with GetRec'#13#10'  do with Item do Other := Count;'
  else if aCase = 'prefix-stmt-parent' then
    lBody := '  with GetRec do begin'#13#10 +
      '  Item2.Other := 5; with Item do Other := Count;'#13#10'  end;'
  else if aCase = 'np2-if' then
    lBody := '  if K = 2 then with Item do Other := 5;'
  else if aCase = 'if-then-else' then
    lBody := '  with GetRec do if K = 2 then with Item do Other := Count else Item2.Other := 5;'
  else if aCase = 'case-label' then
    lBody := '  with GetRec do case K of 1: with Item do Other := Count; 2: Item2.Other := 5; end;'
  else if aCase = 'three-planned-mid' then
    lBody := '  with GetRec do with Item do with Item2 do Other := Count;'
  else if aCase = 'two-children' then
    lBody := '  with GetRec do begin with Item do Other := Count; with Item2 do Other := Count; end;'
  else if aCase = 'following-stmt' then
    lBody := '  with GetRec do with Item do Other := Count; Item2.Other := 5;'
  else if aCase = 'planned-parent' then
    lBody := '  with Item do with Item2 do Other := 5;'
  else if aCase = 'outer-if-else-sameline' then
    lBody := '  if K = 2 then with GetRec do with Item do Other := Count else Item2.Other := 5;';
  Assert.AreNotEqual('', lBody, aCase);
  lPath := WithBinderTempPath('DS740-' + aCase + '.pas');
  lSource := 'unit Unit1;'#13#10'interface'#13#10 +
    'type TRec = record const Count = 7; end;'#13#10 +
    'TInner = record Other: Integer; procedure Touch; end;'#13#10 +
    'var Item, Item2: TInner; Count, K: Integer;'#13#10'implementation'#13#10 +
    'function GetRec: TRec; begin Result := Default(TRec); end;'#13#10 +
    'procedure TInner.Touch; begin end;'#13#10 +
    'procedure Run;'#13#10'begin'#13#10'  K := 1;'#13#10 +
    lBody + #13#10'end;'#13#10'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  SetLength(lModels, 1);
  lModels[0] := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModels[0].Success, aCase);
  lFacts := TDelphiSemanticWithBinder.BindProject('ds740-prefix', nil, lModels);
  lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
  lSnapshotPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWithCompatibilitySnapshot(lFacts);
  lFound := False;
  for var i := 0 to High(lPlan.FinalStatements) do
  begin
    lStatement := lPlan.FinalStatements[i];
    Assert.AreEqual(lStatement.Status, lSnapshotPlan.FinalStatements[i].Status, aCase);
    Assert.AreEqual(lStatement.ReplacementText, lSnapshotPlan.FinalStatements[i].ReplacementText, aCase);
    if not SameText(lStatement.Status, 'planned') then
      Continue;
    for lEdit in lStatement.Edits do
      if lEdit.Kind = 'replace-statement' then
      begin
        lFound := True;
        if aCase = 'planned-parent' then
          Assert.AreEqual(1, lEdit.Range.StartColumn,
            'Whitespace-only indentation can be included in the parent edit.')
        else
          Assert.AreEqual(lStatement.Range.StartColumn, lEdit.Range.StartColumn,
            aCase + ': the prefix belongs to the surrounding statement.');
        if (aCase = 'prefix-stmt-parent') or (aCase = 'two-children') or
          (aCase = 'planned-parent') then
        begin
          Assert.IsFalse(ContainsText(lEdit.ReplacementText, 'begin'),
            aCase + ': statement sequences and absorbed children stay unwrapped.');
          Assert.IsTrue(ContainsText(lEdit.ReplacementText, ':='), aCase);
          Continue;
        end;
        Assert.IsTrue(StartsText('begin' + sLineBreak, lEdit.ReplacementText), aCase);
        lExpectedEnd := 'end;';
        if (aCase = 'if-then-else') or (aCase = 'outer-if-else-sameline') then
          lExpectedEnd := 'end';
        Assert.IsTrue(EndsText(sLineBreak + StringOfChar(' ',
          lEdit.Range.StartColumn - 1) + lExpectedEnd, lEdit.ReplacementText),
          aCase + ': complete block and correct outer separator required.');
      end;
  end;
  Assert.IsTrue(lFound, aCase + ': expected a nonempty planned rewrite.');
end;

procedure TWithBinderTests.PrefixControlUsesActivity(const aActivity: string);
var
  i: Integer;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticApiOptions;
  lPath, lDirective, lPrefix, lSource: string;
  lControlled: Boolean;
  lPlan, lSnapshotPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lDirective := '{$IFDEF DS740_DISABLED}';
  if aActivity = 'active' then
    lDirective := '{$IFDEF MSWINDOWS}'
  else if aActivity = 'unknown' then
    lDirective := '{$IF UseFast}';
  lControlled := True;
  lPrefix := '  ' + lDirective + ' if K = 2 then {$ENDIF} { prefix trivia }';
  if aActivity = 'net-statement' then
  begin
    lPrefix := '  {$IFDEF NET} Item.Touch; {$ENDIF}';
    lControlled := True;
  end else if aActivity = 'net-control' then
  begin
    lPrefix := '  {$IFDEF NET} if K = 2 then {$ENDIF}';
  end else if aActivity = 'two-statements' then
  begin
    lPrefix := '  {$IFDEF NET} Item.Touch; {$ENDIF}' + #13#10 +
      '  {$IFDEF DS740_OTHER} Item.Touch; {$ENDIF}';
    lControlled := True;
  end else if aActivity = 'two-control' then
  begin
    lPrefix := '  {$IFDEF NET} if K = 2 then {$ENDIF}' + #13#10 +
      '  {$IFDEF DS740_OTHER} Item.Touch; {$ENDIF}';
  end;
  if aActivity = 'complementary-control' then
    lPrefix := '  {$IFDEF NET} if K = 2 then {$ENDIF}' + #13#10 +
      '  {$IFNDEF NET} Item.Touch; {$ENDIF}'
  else if aActivity = 'active-control' then
    lPrefix := '  {$IFDEF NET} if K = 2 then {$ENDIF}' + #13#10 +
      '  {$IFDEF MSWINDOWS} Item.Touch; {$ENDIF}'
  else if aActivity = 'active-statement' then
  begin
    lPrefix := '  {$IFDEF MSWINDOWS} Item.Touch; {$ENDIF}';
    lControlled := True;
  end;
  if aActivity = 'include' then
    lPrefix := '  {$I cond.inc}'
  else if (aActivity = 'while') or (aActivity = 'while-inline') then
    lPrefix := '  while K = 2 do'
  else if (aActivity = 'for') or (aActivity = 'for-inline') then
    lPrefix := '  for K := 1 to 0 do'
  else if aActivity = 'comments' then
    lPrefix := '  if K = 2 then { ; } (* ; *) // ;'
  else if aActivity = 'label' then
    lPrefix := 'L1:'
  else if aActivity = 'string' then
  begin
    lPrefix := '  K := Length(''{$I missing.inc} (*$IFDEF X*)'');';
    lControlled := False;
  end else if (aActivity = 'routine-ifdef') or (aActivity = 'expression-ifdef') then
  begin
    lPrefix := '  K := 0;';
    if aActivity = 'expression-ifdef' then
      lPrefix := '  K := {$IFDEF MSWINDOWS} 0 {$ELSE} 1 {$ENDIF};';
    lControlled := False;
  end;
  lPath := WithBinderTempPath('DS740-prefix-' + aActivity);
  lSource := 'unit Unit1;'#13#10'interface'#13#10 +
    'const UseFast = True;'#13#10 +
    'type TInner = record Other: Integer; procedure Touch; end;'#13#10 +
    'var Item: TInner; K: Integer;'#13#10'implementation'#13#10 +
    'procedure TInner.Touch; begin end;'#13#10 +
    'procedure Run;'#13#10'begin'#13#10'  K := 0;'#13#10 +
    lPrefix + #13#10 +
    '  with Item do Other := 5;'#13#10'end;'#13#10'end.';
  if (aActivity = 'while-inline') or (aActivity = 'for-inline') then
    lSource := StringReplace(lSource, lPrefix + #13#10,
      lPrefix + ' ', []);
  if aActivity = 'routine-ifdef' then
    lSource := StringReplace(lSource, 'procedure Run;', '{$IFDEF MSWINDOWS}'#13#10 +
      'procedure Run;', []);
  if aActivity = 'routine-ifdef' then
    Insert('{$ENDIF}'#13#10, lSource, Length(lSource) - 3);
  if aActivity = 'label' then
    lSource := StringReplace(lSource, 'procedure Run;', 'procedure Run; label L1;', []);
  if (aActivity = 'partial-cascade') or (aActivity = 'cb-sib') or
    StartsText('planned-', aActivity) then
    lSource :=
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'uses System.SysUtils;'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TItem = record'#13#10 +
      '  var A: Integer;'#13#10 +
      '  const Count = 7;'#13#10 +
      ' end;'#13#10 +
      ' TAlias = TItem;'#13#10 +
      ' TItemV = record'#13#10 +
      '  A: Integer;'#13#10 +
      '  const Count = 7;'#13#10 +
      ' end;'#13#10 +
      ' TOther = record'#13#10 +
      '  B: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TExtra = record'#13#10 +
      '  C: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TO2 = record'#13#10 +
      '  B: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TO2A = TO2;'#13#10 +
      'var'#13#10 +
      ' Item, Item2: TAlias;'#13#10 +
      ' ItemV: TItemV;'#13#10 +
      ' Other: TOther;'#13#10 +
      ' Extra: TExtra;'#13#10 +
      ' Other2: TO2A;'#13#10 +
      'var A: Integer = 0;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      'with Item do begin A := 5; with Other do B := Count; try A := 6; except on Exception do with Extra do C := 1; end; end;'#13#10 +
      'Writeln(Item.A, '' '', Other.B, '' '', Extra.C);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10;
  if StartsText('planned-', aActivity) then
  begin
    lPrefix := 'while B < 8 do with Extra do begin C := C + 1; B := B + 1; end;';
    if aActivity = 'planned-for' then
      lPrefix := 'for i := 1 to 2 do with Extra do begin C := C + 1; B := B + 1; end;'
    else if aActivity = 'planned-on' then
      lPrefix := 'try B := 7; except on Exception do with Extra do begin C := 1; B := B + 1; end; end;';
    lSource := Copy(lSource, 1, Pos('implementation', lSource) - 1) +
      'implementation'#13#10'procedure Run;'#13#10'begin'#13#10 +
      'with Other do begin B := 6; ' + lPrefix + ' end;'#13#10 +
      'Writeln(Other.B, '' '', Extra.C);'#13#10'end;'#13#10'end.'#13#10;
    if aActivity = 'planned-for' then
      lSource := StringReplace(lSource, 'implementation'#13#10'procedure Run;',
        'implementation'#13#10'procedure Run;'#13#10'var i: Integer;', []);
  end else if aActivity = 'cb-sib' then
    lSource := StringReplace(lSource, 'try A := 6;', 'try Abort;', []);
  TDirectory.CreateDirectory(lPath);
  if aActivity = 'include' then
    TFile.WriteAllText(TPath.Combine(lPath, 'cond.inc'), 'if K = 2 then', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lPath, 'Unit1.pas'), lSource, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lPath, 'P.dpr'),
    'program P; uses Unit1; begin end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lPath, 'P.dproj'),
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="Unit1.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.Combine(lPath, 'P.dproj');
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win64';
  lOptions.DelphiVersion := '23.0';
  lOptions.Cache.SqliteCacheFileName := TPath.Combine(lPath, 'prefix-cache.sqlite');
  if TFile.Exists(lOptions.Cache.SqliteCacheFileName) then
    TFile.Delete(lOptions.Cache.SqliteCacheFileName);
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
  lSnapshotPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWithCompatibilitySnapshot(lFacts);
  if StartsText('planned-', aActivity) or (aActivity = 'cb-sib') then
  begin
    if aActivity = 'cb-sib' then
    begin
      Assert.AreEqual<Integer>(3, Length(lPlan.FinalStatements), aActivity);
      Assert.AreEqual('skipped', lPlan.FinalStatements[0].Status, aActivity);
      Assert.AreEqual('symbol-not-found', lPlan.FinalStatements[0].Reason, aActivity);
      Assert.AreEqual<Integer>(0, Length(lPlan.FinalStatements[0].Edits), aActivity);
    end else begin
      Assert.AreEqual<Integer>(1, Length(lPlan.FinalStatements), aActivity);
      Assert.AreEqual('planned', lPlan.FinalStatements[0].Status, aActivity);
      lPrefix := lPlan.FinalStatements[0].ReplacementText;
      Assert.IsTrue(Pos(' do', lPrefix) > 0, aActivity);
      lPrefix := TrimLeft(Copy(lPrefix, Pos(' do', lPrefix) + 3, MaxInt));
      Assert.IsTrue(StartsText('begin' + sLineBreak, lPrefix),
        aActivity + ': controlled child inside planned parent must be wrapped.');
    end;
    Assert.AreEqual<Integer>(Length(lPlan.FinalStatements),
      Length(lSnapshotPlan.FinalStatements), aActivity);
    for i := 0 to High(lPlan.FinalStatements) do
    begin
      lStatement := lPlan.FinalStatements[i];
      Assert.AreEqual(lStatement.Status, lSnapshotPlan.FinalStatements[i].Status, aActivity);
      Assert.AreEqual(lStatement.Reason, lSnapshotPlan.FinalStatements[i].Reason, aActivity);
      Assert.AreEqual(lStatement.ReplacementText,
        lSnapshotPlan.FinalStatements[i].ReplacementText, aActivity);
      if i = 0 then
        Continue;
      Assert.AreEqual('planned', lStatement.Status, aActivity);
      Assert.IsTrue(Length(lStatement.Edits) > 0, aActivity);
      if i = 2 then
      begin
        Assert.IsTrue(StartsText('begin' + sLineBreak,
          TrimLeft(lStatement.ReplacementText)), aActivity + ': handler child must be wrapped.');
      end;
    end;
    Exit;
  end;
  if aActivity = 'partial-cascade' then
  begin
    Assert.AreEqual<Integer>(1, Length(lPlan.FinalStatements), aActivity);
    Assert.AreEqual<Integer>(1, Length(lSnapshotPlan.FinalStatements), aActivity);
    Assert.AreEqual('planned', lPlan.FinalStatements[0].Status);
    Assert.AreEqual(DS741ExpectedReplacement(aActivity), lPlan.FinalStatements[0].ReplacementText);
    Assert.AreEqual(DS741ExpectedReplacement(aActivity), lSnapshotPlan.FinalStatements[0].ReplacementText);
    Exit;
  end;
  Assert.AreEqual<Integer>(1, Length(lPlan.FinalStatements), aActivity);
  Assert.AreEqual<Integer>(1, Length(lSnapshotPlan.FinalStatements), aActivity);
  lStatement := lPlan.FinalStatements[0];
  Assert.AreEqual(lStatement.Status, lSnapshotPlan.FinalStatements[0].Status, aActivity);
  Assert.AreEqual(lStatement.Reason, lSnapshotPlan.FinalStatements[0].Reason, aActivity);
  Assert.AreEqual(lStatement.ReplacementText,
    lSnapshotPlan.FinalStatements[0].ReplacementText, aActivity);
  Assert.AreEqual('planned', lStatement.Status, aActivity);
  Assert.IsTrue(Length(lStatement.Edits) > 0, aActivity);
  Assert.IsTrue(ContainsText(lStatement.ReplacementText, ':='), aActivity);
  // Even a currently inactive guard may control this statement in another build.
  Assert.AreEqual(lControlled, StartsText('begin' + sLineBreak,
    TrimLeft(lStatement.ReplacementText)), aActivity);
end;

type
  // Even positive terminal-root evidence cannot prove a generic ancestor's members.
  TDS750RootAbsence = class(TInterfacedObject, IDelphiSemanticImplicitRootMemberAbsence,
    IDelphiSemanticNamedRootMemberAbsence)
  public
    function EvidenceFingerprint: string;
    function IsNameAbsent(const aName: string): Boolean;
    function IsNamedRootMemberAbsent(const aRoot: TDelphiSemanticQualifiedRootType;
      const aSiteUnits: TArray<string>; const aName: string): Boolean;
  end;

function TDS750RootAbsence.EvidenceFingerprint: string;
begin
  Result := 'ds750-generic-ancestor-characterization-v1';
end;

function TDS750RootAbsence.IsNameAbsent(const aName: string): Boolean;
begin
  Result := True;
end;

function TDS750RootAbsence.IsNamedRootMemberAbsent(
  const aRoot: TDelphiSemanticQualifiedRootType; const aSiteUnits: TArray<string>;
  const aName: string): Boolean;
begin
  Result := True;
end;

function DS750GenericAncestorSource(const aShape: string; const aCompact: Boolean): string;
var
  lBase, lExtra, lImplementation, lGlobals, lGlobalImplementation: string;
  lInitialization, lBody, lOutput, lHeading: string;
begin
  lBase := 'TList<Integer>';
  lExtra := '';
  lImplementation := '';
  lGlobals := 'GlobalAdd: Integer;'#13#10'procedure Add(aValue: Integer);';
  lGlobalImplementation := 'procedure Add(aValue: Integer);'#13#10'begin'#13#10 +
    ' GlobalAdd := aValue;'#13#10'end;';
  lInitialization := '';
  lBody := 'Add(5)';
  lOutput := 'Writeln(L.Count, '' '', GlobalAdd);';
  if aShape = 'list-count' then
  begin
    lGlobals := 'Count: Integer = 7;'#13#10'X: Integer;';
    lGlobalImplementation := '';
    lInitialization := 'L.Add(5);';
    lBody := 'X := Count';
    lOutput := 'Writeln(X, '' '', Count);';
  end else if aShape = 'list-items' then
  begin
    lGlobals := 'Items: array[0..0] of Integer = (7);'#13#10'X: Integer;';
    lGlobalImplementation := '';
    lInitialization := 'L.Add(5);';
    lBody := 'X := Items[0]';
    lOutput := 'Writeln(X, '' '', Items[0]);';
  end else if aShape = 'dictionary' then
  begin
    lBase := 'TDictionary<Integer,Integer>';
    lGlobals := 'GlobalContainsKey: Integer;'#13#10'X: Boolean;'#13#10 +
      'function ContainsKey(aKey: Integer): Boolean;';
    lGlobalImplementation := 'function ContainsKey(aKey: Integer): Boolean;'#13#10 +
      'begin'#13#10' Inc(GlobalContainsKey);'#13#10' Result := False;'#13#10'end;';
    lInitialization := 'L.Add(5, 9);';
    lBody := 'X := ContainsKey(5)';
    lOutput := 'Writeln(Ord(X), '' '', GlobalContainsKey);';
  end else if StartsText('project', aShape) then
  begin
    lExtra := 'TMyList<T> = class'#13#10'public'#13#10' Value: T;'#13#10 +
      ' procedure Add(aValue: T);'#13#10'end;'#13#10;
    lImplementation := 'procedure TMyList<T>.Add(aValue: T);'#13#10 +
      'begin'#13#10' Value := aValue;'#13#10'end;'#13#10;
    lBase := 'TMyList<Integer>';
    if aShape = 'project-depth2' then
    begin
      lExtra := lExtra + 'TIntermediate = class(TMyList<Integer>) end;'#13#10;
      lBase := 'TIntermediate';
    end;
    lOutput := 'Writeln(L.Value, '' '', GlobalAdd);';
  end;
  lHeading := 'TIntList = class(' + lBase + ')'#13#10'end;'#13#10;
  if aCompact then
    lHeading := 'TIntList=class(' + lBase + ') end;'#13#10;
  Result := 'unit Unit1;'#13#10'interface'#13#10'uses System.Generics.Collections;'#13#10 +
    'type'#13#10 + lExtra + lHeading + 'var'#13#10' L: TIntList;'#13#10 +
    lGlobals + #13#10'procedure Run;'#13#10'implementation'#13#10 +
    lImplementation + lGlobalImplementation + #13#10'procedure Run;'#13#10 +
    'begin'#13#10' L := TIntList.Create;'#13#10' try'#13#10 +
    lInitialization + #13#10'  with L do ' + lBody + ';'#13#10 + lOutput + #13#10 +
    ' finally'#13#10'  L.Free;'#13#10' end;'#13#10'end;'#13#10'end.'#13#10;
end;

procedure TWithBinderTests.GenericAncestorHomonymsRefuse(const aShape: string;
  const aCompact: Boolean; const aMode: string);
var
  g: TGarbos;
  lRoot: string;
  lOptions: TDelphiSemanticApiOptions;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lStored, lLoaded: TDelphiProjectSnapshot;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lSession: TDelphiSemanticProjectSessionResult;
  lBuild: TDelphiSemanticRemoveWithPlanBuildResult;
begin
  lRoot := WithBinderTempPath('ds750-' + aShape + '-' + BoolToStr(aCompact, True) + '-' + aMode);
  TDirectory.CreateDirectory(lRoot);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
    DS750GenericAncestorSource(aShape, aCompact), TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P;'#13#10'{$APPTYPE CONSOLE}'#13#10'uses Unit1;'#13#10'begin Run; end.'#13#10,
    TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dproj'),
    '<Project><PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="Unit1.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := TPath.Combine(lRoot, 'P.dproj');
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win64';
  lOptions.DelphiVersion := '23.0';
  lOptions.Cache.SqliteCacheFileName := TPath.Combine(lRoot, 'session.sqlite');
  // Session persistence requires the default provider; the explicit snapshot routes
  // additionally challenge the ancestry guard with positive terminal-root evidence.
  if not MatchText(aMode, ['sessioncold', 'sessionwarm']) then
    lOptions.ImplicitRootMemberAbsence := TDS750RootAbsence.Create;
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
  if aMode = 'snapshot' then
    lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWithCompatibilitySnapshot(lFacts);
  // DS-760 owns project-generic SQLite reload; those cases cover only routes that load.
  if aMode = 'standalone' then
  begin
    lIdentity := Default(TDelphiSemanticSnapshotCacheIdentity);
    lIdentity.CacheKey := 'ds750';
    lIdentity.IdentityKey := lIdentity.CacheKey;
    lIdentity.SourceFileName := lOptions.ProjectFileName;
    lIdentity.FileHash := lFacts.ContextFingerprint;
    lIdentity.ContextHash := lFacts.ContextFingerprint;
    lIdentity.IncludeGraphHash := 'no-includes';
    lIdentity.SchemaVersion := 'ds750';
    GC(lStored, BuildCompatibilityRemoveWithPlanningSnapshotFromFacts(lFacts), g);
    GC(lCache, TDelphiSemanticSnapshotSqliteCache.Create(TPath.Combine(lRoot, 'standalone.sqlite')), g);
    lCache.StoreProjectRemoveWithPlanningFacts(lIdentity, lStored, lFacts.Symbols);
    Assert.IsTrue(lCache.TryLoadProjectRemoveWithPlanningFacts(lIdentity, lLoaded));
    GC(lLoaded, g);
    lPlan := TDelphiSemanticRemoveWithPlanner.Plan(lLoaded);
  end;
  if MatchText(aMode, ['sessioncold', 'sessionwarm']) then
    for var i := 0 to Ord(aMode = 'sessionwarm') do
    begin
      lSession := TDelphiSemanticProjectSession.Open(ProjectOptionsFromApiOptions(lOptions));
      try
        Assert.IsTrue(lSession.Success);
        lBuild := lSession.Session.PlanRemoveWithResult;
        if not StartsText('project', aShape) then
          Assert.AreEqual(i, Integer(lBuild.SnapshotMetrics.SnapshotCacheHits));
        lPlan := lBuild.Plan;
      finally
        lSession.Session.Free;
      end;
    end;
  Assert.AreEqual<Integer>(1, Length(lPlan.FinalStatements));
  Assert.AreEqual('skipped', lPlan.FinalStatements[0].Status);
  Assert.AreEqual('OWNER_INHERITED_MEMBERS_UNVERIFIED', lPlan.FinalStatements[0].SafetyReason);
  Assert.AreEqual('', lPlan.FinalStatements[0].ReplacementText);
  Assert.AreEqual<Integer>(0, Length(lPlan.FinalStatements[0].Edits));
  Assert.AreEqual<Integer>(0, Length(lPlan.FinalStatements[0].Temps));
  Assert.AreEqual<Integer>(0, Length(lPlan.Edits));
end;

initialization
  TDUnitX.RegisterTestFixture(TWithBinderTests);

end.
