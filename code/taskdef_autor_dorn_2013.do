* ============================================================================
* TASK DEFINITION: Autor & Dorn (2013) - abstract / routine / manual
* ============================================================================
* The three task aggregates behind Autor & Dorn's routine task intensity
* (RTI) index, the workhorse of the job-polarization literature.
*
* PROVENANCE CAVEAT: the original Autor-Dorn measures come from the 1977
* DOT, not from O*NET. This file is the standard O*NET adaptation used in
* the later literature: the three aggregates are built from the same O*NET
* elements as the Acemoglu & Autor (2011) composites -
*   abstract = nrca + nrci elements   (6 elements)
*   routine  = rc + rm elements       (6 elements)
*   manual   = nrmp elements          (4 elements)
* so this definition differs from taskdef_acemoglu_autor_2011.do only in how
* the same 16 elements are grouped.
*
* RTI is NOT computed here: with standardized composites the original
* ln(R)-ln(A)-ln(M) is undefined (z-scores are negative), and the literature's
* z-score version is a linear combination -
*   rti = task_routine_z - task_abstract_z - task_manual_z
* - which commutes with the unweighted means used at every crosswalk leg, so
* computing it from the FEOR-level output is identical to crosswalking an
* occupation-level RTI. Build it downstream in one line.
*
* References: Autor & Dorn (2013), "The Growth of Low-Skill Service Jobs and
* the Polarization of the US Labor Market", AER 103(5); Acemoglu & Autor
* (2011), Handbook of Labor Economics 4B, for the O*NET element sets.
*
* Token format for every element:  SCALE:ELEMENTID
*   SCALE     = O*NET scale to read (IM = Importance, LV = Level, CX = Context)
*   ELEMENTID = O*NET Content Model element id, dotted (e.g. 4.A.2.a.4)
* ============================================================================

* --- Start from a clean slate ----------------------------------------------
* When several definitions are built in one master run, a global that THIS
* definition does not set would otherwise silently leak in from the
* previously loaded definition.
capture macro drop taskcats taskdef_name rev_els
capture macro drop els_*
capture macro drop lab_*

* --- Identity ---------------------------------------------------------------
global taskdef_name "autor-dorn-2013"

* Ordered list of task-category codes
global taskcats "abstract routine manual"

* --- Elements per category (SCALE:ELEMENTID) ------------------------------

* Abstract: non-routine cognitive, analytical + interpersonal
*   4.A.2.a.4  Analyzing Data or Information
*   4.A.2.b.2  Thinking Creatively
*   4.A.4.a.1  Interpreting the Meaning of Information for Others
*   4.A.4.a.4  Establishing and Maintaining Interpersonal Relationships
*   4.A.4.b.4  Guiding, Directing, and Motivating Subordinates
*   4.A.4.b.5  Coaching and Developing Others
global els_abstract "IM:4.A.2.a.4 IM:4.A.2.b.2 IM:4.A.4.a.1 IM:4.A.4.a.4 IM:4.A.4.b.4 IM:4.A.4.b.5"

* Routine: routine cognitive + routine manual
*   4.C.3.b.7   Importance of Repeating Same Tasks
*   4.C.3.b.4   Importance of Being Exact or Accurate
*   4.C.3.b.8   Structured versus Unstructured Work  (reverse-coded)
*   4.C.3.d.3   Pace Determined by Speed of Equipment
*   4.A.3.a.3   Controlling Machines and Processes
*   4.C.2.d.1.i Spend Time Making Repetitive Motions
global els_routine "CX:4.C.3.b.7 CX:4.C.3.b.4 CX:4.C.3.b.8 CX:4.C.3.d.3 IM:4.A.3.a.3 CX:4.C.2.d.1.i"

* Manual: non-routine manual, physical
*   4.A.3.a.4   Operating Vehicles, Mechanized Devices, or Equipment
*   4.C.2.d.1.g Spend Time Using Your Hands to Handle, Control, or Feel Objects
*   1.A.2.a.2   Manual Dexterity
*   1.A.1.f.1   Spatial Orientation
global els_manual "IM:4.A.3.a.4 CX:4.C.2.d.1.g IM:1.A.2.a.2 IM:1.A.1.f.1"

* --- Elements to reverse-code (higher raw value = LESS of the task) --------
*   Structured vs Unstructured Work: high value = autonomy = less routine
global rev_els "CX:4.C.3.b.8"

* --- Human-readable labels for each category ------------------------------
global lab_abstract "Abstract tasks"
global lab_routine  "Routine tasks"
global lab_manual   "Manual tasks"
