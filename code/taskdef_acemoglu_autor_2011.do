* ============================================================================
* TASK DEFINITION: Acemoglu & Autor (2011)
* ============================================================================
* This is the ONE place the task taxonomy is defined: which O*NET elements
* (and on which scale) make up each task composite, and which elements are
* reverse-coded. To try a different task definition, copy this file, edit the
* lists below (including $taskdef_name), and add it to the `defs' list in
* 00_master.do - nothing else changes. Several definitions can be built in the
* same run; each writes to its own folder, named by $taskdef_name.
*
* Reference: Acemoglu & Autor (2011), "Skills, Tasks and Technologies:
* Implications for Employment and Earnings", Handbook of Labor Economics 4B.
* The Importance (IM) scale is used for Abilities / Work Activities elements
* and the Context (CX) scale for Work Context elements.
*
* Token format for every element:  SCALE:ELEMENTID
*   SCALE     = O*NET scale to read (IM = Importance, LV = Level, CX = Context)
*   ELEMENTID = O*NET Content Model element id, dotted (e.g. 4.A.2.a.4)
*
* NOTE: the globals below hold the task SPECIFICATION, not file paths. They
* are the mechanism for passing the definition to the import/build steps.
* ============================================================================

* --- Start from a clean slate ----------------------------------------------
* When several definitions are built in one master run, a global that THIS
* definition does not set (e.g. $rev_els, if it reverse-codes nothing) would
* otherwise silently leak in from the previously loaded definition.
capture macro drop taskcats taskdef_name rev_els
capture macro drop els_*
capture macro drop lab_*

* --- Identity ---------------------------------------------------------------
* Short slug for this definition. It names the output folders
* (output/<year>/$taskdef_name/, output/$taskdef_name/ for the panel) and this
* definition's temp/ subfolders, so definitions never overwrite each other.
* Keep it filesystem-safe.
global taskdef_name "acemoglu-autor-2011"

* Ordered list of task-category codes
global taskcats "nrca nrci rc rm nrmp"

* --- Elements per category (SCALE:ELEMENTID) ------------------------------

* Non-routine cognitive: analytical
*   4.A.2.a.4  Analyzing Data or Information
*   4.A.2.b.2  Thinking Creatively
*   4.A.4.a.1  Interpreting the Meaning of Information for Others
global els_nrca "IM:4.A.2.a.4 IM:4.A.2.b.2 IM:4.A.4.a.1"

* Non-routine cognitive: interpersonal
*   4.A.4.a.4  Establishing and Maintaining Interpersonal Relationships
*   4.A.4.b.4  Guiding, Directing, and Motivating Subordinates
*   4.A.4.b.5  Coaching and Developing Others
global els_nrci "IM:4.A.4.a.4 IM:4.A.4.b.4 IM:4.A.4.b.5"

* Routine cognitive
*   4.C.3.b.7  Importance of Repeating Same Tasks
*   4.C.3.b.4  Importance of Being Exact or Accurate
*   4.C.3.b.8  Structured versus Unstructured Work  (reverse-coded)
global els_rc "CX:4.C.3.b.7 CX:4.C.3.b.4 CX:4.C.3.b.8"

* Routine manual
*   4.C.3.d.3   Pace Determined by Speed of Equipment
*   4.A.3.a.3   Controlling Machines and Processes
*   4.C.2.d.1.i Spend Time Making Repetitive Motions
global els_rm "CX:4.C.3.d.3 IM:4.A.3.a.3 CX:4.C.2.d.1.i"

* Non-routine manual: physical
*   4.A.3.a.4   Operating Vehicles, Mechanized Devices, or Equipment
*   4.C.2.d.1.g Spend Time Using Your Hands to Handle, Control, or Feel Objects
*   1.A.2.a.2   Manual Dexterity
*   1.A.1.f.1   Spatial Orientation
global els_nrmp "IM:4.A.3.a.4 CX:4.C.2.d.1.g IM:1.A.2.a.2 IM:1.A.1.f.1"

* --- Elements to reverse-code (higher raw value = LESS of the task) --------
*   Structured vs Unstructured Work: high value = autonomy = less routine
global rev_els "CX:4.C.3.b.8"

* --- Human-readable labels for each category ------------------------------
global lab_nrca "Non-routine cognitive: analytical"
global lab_nrci "Non-routine cognitive: interpersonal"
global lab_rc   "Routine cognitive"
global lab_rm   "Routine manual"
global lab_nrmp "Non-routine manual: physical"
