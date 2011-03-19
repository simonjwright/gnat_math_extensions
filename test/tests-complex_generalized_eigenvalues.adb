--  This package is free software; you can redistribute it and/or
--  modify it under terms of the GNU General Public License as
--  published by the Free Software Foundation; either version 3, or
--  (at your option) any later version.  It is distributed in the
--  hope that it will be useful, but WITHOUT ANY WARRANTY; without
--  even the implied warranty of MERCHANTABILITY or FITNESS FOR A
--  PARTICULAR PURPOSE.
--
--  You should have received a copy of the GNU General Public License
--  along with this program; see the file COPYING3.  If not, see
--  <http://www.gnu.org/licenses/>.
--
--  Copyright Simon Wright <simon@pushface.org>

with AUnit.Test_Cases; use AUnit.Test_Cases;

with Ada.Numerics.Generic_Real_Arrays;
with Ada.Numerics.Generic_Complex_Types;
with Ada.Numerics.Generic_Complex_Arrays;
with Ada_Numerics.Generic_Arrays;
with System.Generic_Array_Operations;

with Ada.Text_IO.Complex_IO; use Ada.Text_IO;
--  May not be referenced for released versions
pragma Warnings (Off, Ada.Text_IO);
pragma Warnings (Off, Ada.Text_IO.Complex_IO);

package body Tests.Complex_Generalized_Eigenvalues is

   --  This test suite is written as a two-level generic, because it
   --  turns out that the same input gives wildly different results
   --  depending on the precision (unlike other algorithms).

   --  The outer generic instantiates the required types, the inner
   --  one supplies the appropriate inputs and outputs depending on
   --  the precision.

   generic
      type Real is digits <>;
      Type_Name : String;
   package Tests_G is

      package Real_Arrays
      is new Ada.Numerics.Generic_Real_Arrays (Real);
      package Complex_Types
      is new Ada.Numerics.Generic_Complex_Types (Real);
      package Complex_Arrays
      is new Ada.Numerics.Generic_Complex_Arrays (Real_Arrays, Complex_Types);
      package Extensions
      is new Ada_Numerics.Generic_Arrays (Complex_Arrays);

      subtype Generalized_Eigenvalue_Vector
         is Extensions.Generalized_Eigenvalue_Vector;

      --  The actual tests.
      --  If Expected_Betas has a null range, Expected_Alphas is the ratio.
      generic
         Input_A               : Complex_Arrays.Complex_Matrix;
         Input_B               : Complex_Arrays.Complex_Matrix;
         Expected_Alphas       : Complex_Arrays.Complex_Vector;
         Expected_Betas        : Complex_Arrays.Complex_Vector;
         Expected_Eigenvectors : Complex_Arrays.Complex_Matrix;
         Limit                 : Real;
         Additional_Naming     : String := "";
      package Impl is
         function Suite return AUnit.Test_Suites.Access_Test_Suite;
      end Impl;

      function Transpose (M : Complex_Arrays.Complex_Matrix)
                         return Complex_Arrays.Complex_Matrix;
      --  Useful for constructing eigenvector matrices, with their
      --  Fortran-based organization by column.

   end Tests_G;

   package body Tests_G is

      use Real_Arrays;
      use Complex_Types;
      use Complex_Arrays;

      package Real_IO is new Float_IO (Real);
      package My_Complex_IO is new Complex_IO (Complex_Types);

      use Real_IO;
      use My_Complex_IO;

      function Close_Enough (L, R : Complex_Vector) return Boolean;
      function Close_Enough (L, R : Complex_Matrix) return Boolean;
      function Close_Enough (L, R : Real_Vector) return Boolean;
      function Close_Enough (L, R : Real_Matrix) return Boolean;
      function Column (V : Complex_Matrix; C : Integer) return Complex_Vector;

      package body Impl is

         procedure Eigensystem_Constraints (C : in out Test_Case'Class);
         procedure Eigensystem_Results (C : in out Test_Case'Class);

         type Case_1 is new Test_Case with null record;
         function Name (C : Case_1) return AUnit.Message_String;
         procedure Register_Tests (C : in out Case_1);

         function Name (C : Case_1) return AUnit.Message_String is
            pragma Warnings (Off, C);
         begin
            if Additional_Naming = "" then
               return new String'(Type_Name
                                    & ": Complex_Generalized_Eigenvalues");
            else
               return new String'(Type_Name
                                    & " ("
                                    & Additional_Naming
                                    & "): Complex_Generalized_Eigenvalues");
            end if;
         end Name;

         procedure Register_Tests (C : in out Case_1) is
         begin
            Registration.Register_Routine
              (C,
               Eigensystem_Constraints'Unrestricted_Access,
               "Eigensystem_Constraints");
            Registration.Register_Routine
              (C,
               Eigensystem_Results'Unrestricted_Access,
               "Eigensystem_Results");
         end Register_Tests;

         function Suite return AUnit.Test_Suites.Access_Test_Suite
         is
            Result : constant AUnit.Test_Suites.Access_Test_Suite
              := new AUnit.Test_Suites.Test_Suite;
         begin
            AUnit.Test_Suites.Add_Test (Result, new Case_1);
            return Result;
         end Suite;

         procedure Eigensystem_Constraints (C : in out Test_Case'Class)
         is
            Good_Values : Generalized_Eigenvalue_Vector (Input_A'Range (1));
            Good_Vectors : Complex_Matrix (Input_A'Range (1),
                                           Input_A'Range (2));
         begin
            declare
               Bad_Input : constant Complex_Matrix (1 .. 2, 1 .. 3)
                 := (others => (others => (0.0, 0.0)));
            begin
               Extensions.Eigensystem
                 (A => Bad_Input,
                  B => Input_B,
                  Values => Good_Values,
                  Vectors => Good_Vectors);
               Assert (C, False, "should have raised Constraint_Error (1)");
            exception
               when Constraint_Error => null;
            end;
            declare
               Bad_Input : constant Complex_Matrix (1 .. 2, 1 .. 3)
                 := (others => (others => (0.0, 0.0)));
            begin
               Extensions.Eigensystem
                 (A => Input_A,
                  B => Bad_Input,
                  Values => Good_Values,
                  Vectors => Good_Vectors);
               Assert (C, False, "should have raised Constraint_Error (2)");
            exception
               when Constraint_Error => null;
            end;
            declare
               Bad_Input : constant Complex_Matrix (1 .. Input_A'Length (1),
                                                    1 .. Input_A'Length (2))
                 := (others => (others => (0.0, 0.0)));
            begin
               Extensions.Eigensystem
                 (A => Input_A,
                  B => Bad_Input,
                  Values => Good_Values,
                  Vectors => Good_Vectors);
               Assert (C, False, "should have raised Constraint_Error (3)");
            exception
               when Constraint_Error => null;
            end;
            declare
               Bad_Input : constant Complex_Matrix
                 (Input_A'First (1) .. Input_A'Last (1) - 1,
                  Input_A'First (2) .. Input_A'Last (2) - 1)
                 := (others => (others => (0.0, 0.0)));
            begin
               Extensions.Eigensystem
                 (A => Input_A,
                  B => Bad_Input,
                  Values => Good_Values,
                  Vectors => Good_Vectors);
               Assert (C, False, "should have raised Constraint_Error (4)");
            exception
               when Constraint_Error => null;
            end;
            declare
               Bad_Values :
                 Generalized_Eigenvalue_Vector (1 .. Input_A'Length (1));
            begin
               Extensions.Eigensystem
                 (A => Input_A,
                  B => Input_B,
                  Values => Bad_Values,
                  Vectors => Good_Vectors);
               Assert (C, False, "should have raised Constraint_Error (5)");
            exception
               when Constraint_Error => null;
            end;
            declare
               Bad_Values :
                 Generalized_Eigenvalue_Vector
                 (Input_A'First (1) .. Input_A'Last (1) - 1);
            begin
               Extensions.Eigensystem
                 (A => Input_A,
                  B => Input_B,
                  Values => Bad_Values,
                  Vectors => Good_Vectors);
               Assert (C, False, "should have raised Constraint_Error (6)");
            exception
               when Constraint_Error => null;
            end;
            declare
               Bad_Vectors : Complex_Matrix (1 .. 2, 1 .. 3);
            begin
               Extensions.Eigensystem
                 (A => Input_A,
                  B => Input_B,
                  Values => Good_Values,
                  Vectors => Bad_Vectors);
               Assert (C, False, "should have raised Constraint_Error (7)");
            exception
               when Constraint_Error => null;
            end;
            declare
               Bad_Vectors : Complex_Matrix (1 .. Input_A'Length (1),
                                             1 .. Input_A'Length (2));
            begin
               Extensions.Eigensystem
                 (A => Input_A,
                  B => Input_B,
                  Values => Good_Values,
                  Vectors => Bad_Vectors);
               Assert (C, False, "should have raised Constraint_Error (8)");
            exception
               when Constraint_Error => null;
            end;
         end Eigensystem_Constraints;

         procedure Eigensystem_Results (C : in out Test_Case'Class)
         is
            Values : Generalized_Eigenvalue_Vector (Input_A'Range (1));
            Vectors : Complex_Matrix (Input_A'Range (1), Input_A'Range (2));
         begin

            Extensions.Eigensystem (A => Input_A,
                                    B => Input_B,
                                    Values => Values,
                                    Vectors => Vectors);

            declare
               Alphas : Complex_Vector (Values'Range);
               Betas : Complex_Vector (Values'Range);
            begin
               for J in Values'Range loop
                  Alphas (J) := Values (J).Alpha;
                  Betas (J) := Values (J).Beta;
                  if Expected_Betas'Length = 0 then
                     Alphas (J) := Alphas (J) / Betas (J);
                  end if;
               end loop;
               Assert (C,
                       Close_Enough (Alphas, Expected_Alphas),
                       "incorrect Values.Alpha");
               if Expected_Betas'Length /= 0 then
                  Assert (C,
                          Close_Enough (Betas, Expected_Betas),
                          "incorrect Values.Beta");
               end if;
            end;

            declare
               Test_OK : Boolean := True;
            begin
               for J in Vectors'Range (2) loop
                  if not Close_Enough (Column (Vectors, J),
                                       Column (Expected_Eigenvectors, J)) then
                     Put_Line (".. column:" & J'Img);
                     Test_OK := False;
                  end if;
               end loop;
               Assert (C, Test_OK, "incorrect vectors");
            end;

         end Eigensystem_Results;

      end Impl;

      function Transpose (M : Complex_Matrix) return Complex_Matrix
      is
         procedure Transpose
         is new System.Generic_Array_Operations.Transpose
           (Scalar => Complex,
            Matrix => Complex_Matrix);
      begin
         return Result : Complex_Matrix (M'Range (2), M'Range (1)) do
           Transpose (M, Result);
         end return;
      end Transpose;

      --  This limit may seem a tad on the high side, but all we
      --  really need to know is whether the binding to the LAPACK
      --  subprogram is successful. Experiment shows that putting the
      --  numbers derived from the COMPLEX*16 set into the COMPLEX*8
      --  subprogram gives differences of about 30e.
      --
      --  For cggev, this limit isn't quite enough: maybe the vectors
      --  are rather sensitive?
      Lim : constant Real := Float'Model_Epsilon * 60.0;

      --  The values in Input_A, Input_B, Expected_Alphas,
      --  Expected_Betas, Expected_Eigenvectors were derived from a
      --  run of sggev_generator.


      function Close_Enough (L, R : Complex_Vector) return Boolean
      is
         Result : Boolean := True;
      begin
         if L'Length /= R'Length then
            raise Constraint_Error
              with "Close_Enough(Complex_Vector): different lengths";
         end if;
         for J in L'Range loop
            declare
               Left : Complex renames L (J);
               Right : Complex renames R (J - L'First + R'First);
            begin
               if abs (Left.Re - Right.Re) > Lim
                 or abs (Left.Im - Right.Im) > Lim then
                  Put ("Close_Enough(Complex_Vector): failure:"
                         & " j:" & J'Img
                         & " l:");
                  Put (Left);
                  Put (" r:");
                  Put (Right);
                  Put (" diff:");
                  Put (Left - Right);
                  Put (" lim:");
                  Put (Lim'Img);
                  New_Line;
                  Result := False;
               end if;
            end;
         end loop;
         return Result;
      end Close_Enough;

      function Close_Enough (L, R : Complex_Matrix) return Boolean
      is
         Result : Boolean := True;
      begin
         if L'Length (1) /= R'Length (1)
           or L'Length (2) /= R'Length (2) then
            raise Constraint_Error
              with "Close_Enough(Complex_Matrix): different lengths";
         end if;
         for J in L'Range (1) loop
            for K in L'Range (2) loop
               declare
                  Left : Complex renames L (J, K);
                  Right : Complex renames R (J - L'First (1) + R'First (1),
                                             K - L'First (2) + R'First (2));
               begin
                  if abs (Left.Re - Right.Re) > Lim
                    or abs (Left.Im - Right.Im) > Lim then
                     Put ("Close_Enough(Complex_Matrix): failure:"
                            & " j:" & J'Img
                            & " k:" & K'Img
                            & " l:");
                     Put (Left);
                     Put (" r:");
                     Put (Right);
                     Put (" diff:");
                     Put (Left - Right);
                     Put (" lim:");
                     Put (Lim'Img);
                     New_Line;
                     Result :=  False;
                  end if;
               end;
            end loop;
         end loop;
         return Result;
      end Close_Enough;

      function Close_Enough (L, R : Real_Vector) return Boolean
      is
      begin
         if L'Length /= R'Length then
            raise Constraint_Error
              with "Close_Enough(Real_Vector): different lengths";
         end if;
         for J in L'Range loop
            if abs (L (J) - R (J - L'First + R'First)) > Lim then
               return False;
            end if;
         end loop;
         return True;
      end Close_Enough;

      function Close_Enough (L, R : Real_Matrix) return Boolean
      is
      begin
         if L'Length (1) /= R'Length (1)
           or L'Length (2) /= R'Length (2) then
            raise Constraint_Error
              with "Close_Enough(Real_Matrix): different lengths";
         end if;
         for J in L'Range (1) loop
            for K in L'Range (2) loop
               declare
                  Left : Real renames L (J, K);
                  Right : Real renames R (J - L'First (1) + R'First (1),
                                          K - L'First (2) + R'First (2));
               begin
                  if abs (Left - Right) > Lim then
                     Put_Line ("Close_Enough(Real_Matrix): failure:"
                                 & " j:" & J'Img
                                 & " k:" & K'Img
                                 & " diff:" & Real'Image (abs (Left - Right)));
                     return False;
                  end if;
               end;
            end loop;
         end loop;
         return True;
      end Close_Enough;

      function Column (V : Complex_Matrix; C : Integer) return Complex_Vector
      is
      begin
         return Result : Complex_Vector (V'Range (1)) do
           for J in V'Range (1) loop
              Result (J) := V (J, C);
           end loop;
         end return;
      end Column;

   end Tests_G;

   package Single_Tests is new Tests_G (Float, "Float");
   package Double_Tests is new Tests_G (Long_Float, "Long_Float");
   package Extended_Tests is new Tests_G (Long_Long_Float, "Long_Long_Float");

   --  The data is derived from a run of sggev_generator.
   Single_Input_A :
     constant Single_Tests.Complex_Arrays.Complex_Matrix (3 .. 8,
                                                          13 .. 18) :=
     ((( 0.99755955    , 0.56682467    ),
       ( 0.36739087    , 0.48063689    ),
       ( 0.34708124    , 0.34224379    ),
       ( 0.90052450    , 0.38676596    ),
       ( 1.61082745E-02, 0.65085483    ),
       ( 0.85569239    , 0.40128690    )),
      (( 0.59839952    , 0.67298073    ),
       ( 0.10038292    , 0.75545329    ),
       ( 0.89733458    , 0.65822911    ),
       ( 0.97866023    , 0.99914223    ),
       ( 0.65904748    , 0.55400509    ),
       ( 0.65792465    , 0.72885847    )),
      (( 0.14783514    , 0.67452925    ),
       ( 0.11581880    , 0.61436915    ),
       ( 0.73112863    , 0.49760389    ),
       ( 0.55290300    , 0.99791926    ),
       ( 0.95375901    , 9.32746530E-02),
       ( 0.94684845    , 0.70617634    )),
      (( 6.17055297E-02, 0.48038077    ),
       ( 0.58739519    , 0.51996821    ),
       ( 0.66965729    , 0.66494006    ),
       ( 7.65594840E-02, 0.10124964    ),
       ( 1.51494741E-02, 0.79291540    ),
       ( 0.95358074    , 0.11424434    )),
      (( 4.81528640E-02, 0.11420578    ),
       ( 7.33417869E-02, 0.24686170    ),
       ( 0.56699830    , 2.43123770E-02),
       ( 0.97658539    , 0.69260502    ),
       ( 4.67772484E-02, 0.83977771    ),
       ( 0.73352587    , 0.11604273    )),
      (( 0.74653637    , 0.84320086    ),
       ( 0.73073655    , 0.41060424    ),
       ( 0.47131765    , 0.46262538    ),
       ( 0.25796580    , 0.93770498    ),
       ( 0.90884805    , 0.69487661    ),
       ( 0.74439669    , 0.30111301    )));

   Single_Input_B :
     constant Single_Tests.Complex_Arrays.Complex_Matrix
     (Single_Input_A'Range (1),
      Single_Input_A'Range (2)) :=
     ((( 0.96591532    , 0.74792767    ),
       ( 7.37542510E-02, 5.35517931E-03),
       ( 0.21795171    , 0.13316035    ),
       ( 0.44548225    , 0.66193217    ),
       ( 0.64640880    , 0.32298726    ),
       ( 0.20687431    , 0.96853942    )),
      (( 0.45688230    , 0.33001512    ),
       ( 0.60569322    , 0.71904790    ),
       ( 0.15071678    , 0.61231488    ),
       ( 0.25679797    , 0.55086535    ),
       ( 0.97776008    , 0.90192330    ),
       ( 0.40245521    , 0.92862761    )),
      (( 0.76961428    , 0.33932251    ),
       ( 0.82061714    , 0.94709462    ),
       ( 0.37480170    , 0.42150581    ),
       ( 0.99039471    , 0.74630964    ),
       ( 0.73402363    , 0.75176162    ),
       ( 0.81380963    , 0.55859447    )),
      (( 0.59768975    , 0.13753188    ),
       ( 0.88587832    , 0.30381012    ),
       ( 0.50367689    , 0.26157510    ),
       ( 0.54926568    , 0.37558490    ),
       ( 0.62087750    , 0.77360356    ),
       ( 0.31846261    , 0.59681982    )),
      (( 0.21596491    , 0.10057336    ),
       ( 0.44338423    , 0.20836753    ),
       ( 0.42029053    , 0.39785302    ),
       ( 4.94331121E-03, 0.12992102    ),
       ( 0.67848879    , 0.58195078    ),
       ( 0.84029961    , 0.83499593    )),
      (( 0.52883899    , 0.66548461    ),
       ( 0.35572159    , 0.73537701    ),
       ( 0.75969166    , 0.70245939    ),
       ( 0.45610356    , 0.80848926    ),
       ( 0.21948850    , 0.85495454    ),
       ( 0.67196852    , 0.61871403    )));

   Single_Expected_Alphas :
     constant Single_Tests.Complex_Arrays.Complex_Vector
     (Single_Input_A'Range (1)) :=
     ((-0.72462112    , 0.66605300    ),
      ( 0.38089162    , 0.88627946    ),
      ( 0.61585903    ,-0.64815724    ),
      (-0.64635521    ,-0.12128220    ),
      (  2.2019682    ,-0.74377418    ),
      ( 0.52759075    ,-9.17982757E-02));

   Single_Expected_Betas :
     constant Single_Tests.Complex_Arrays.Complex_Vector
     (Single_Input_A'Range (1)) :=
     (( 0.39223254    ,  0.0000000    ),
      ( 0.47756130    ,  0.0000000    ),
      ( 0.51605523    ,  0.0000000    ),
      ( 0.97219819    ,  0.0000000    ),
      (  2.2389016    ,  0.0000000    ),
      ( 0.94190317    ,  0.0000000    ));

   Single_Expected_Eigenvectors :
     constant Single_Tests.Complex_Arrays.Complex_Matrix
     (Single_Input_A'Range (1),
      Single_Input_B'Range (2)) :=
     (((-3.41690592E-02, 0.34121007    ),
       (-9.06911045E-02,-0.50845200    ),
       ( 1.89757571E-02,-0.29191309    ),
       (-0.19284678    , 0.18012540    ),
       ( 0.29880726    ,-0.13542424    ),
       ( 0.54871058    , 0.17579372    )),
      ((-0.10953330    , 0.64291245    ),
       ( 0.77856314    ,-0.22143684    ),
       ( 0.35502124    ,-0.49379399    ),
       ( 0.70806199    , 0.26557785    ),
       ( 0.12665448    , 0.52514285    ),
       (-0.89201754    ,-0.10798247    )),
      (( 6.70455918E-02,-0.59220606    ),
       (-0.61433345    , 5.71437217E-02),
       ( 0.40359023    ,-7.00188801E-02),
       (-0.89382565    ,-0.10617443    ),
       (-0.11373845    , 0.10914997    ),
       (-0.28644159    , 9.93528366E-02)),
      (( 0.44573134    ,-0.55426866    ),
       (-0.10562851    ,-1.88317858E-02),
       ( 4.39306535E-02, 0.34227726    ),
       ( 0.22148877    ,-0.13514845    ),
       (-0.18817410    ,-7.23348409E-02),
       (-0.28263345    , 3.14227380E-02)),
      ((-0.21147224    ,-0.15393445    ),
       (-0.30253553    , 0.42683592    ),
       (-1.83209926E-02, 0.81524885    ),
       ( 0.25485277    ,-9.91754308E-02),
       (-0.54370803    ,-0.45629200    ),
       ( 0.17893469    ,-0.29209048    )),
      ((-0.19641124    , 0.26479438    ),
       ( 0.32989562    , 9.17730927E-02),
       (-0.73561502    ,-0.26438498    ),
       (-9.23215821E-02,-0.22580478    ),
       ( 0.15508713    ,-0.69760889    ),
       ( 0.32355800    , 0.24944758    )));

   package Single_Impl is new Single_Tests.Impl
     (Input_A => Single_Input_A,
      Input_B => Single_Input_B,
      Expected_Alphas => Single_Expected_Alphas,
      Expected_Betas => Single_Expected_Betas,
      Expected_Eigenvectors => Single_Expected_Eigenvectors,
      Limit => 1.0e-6);

   --  The data is from the ZGGEV example at
   --  http://www.nag.co.uk/lapack-ex/node122.html.
   package Double_Impl_NAG is new Double_Tests.Impl
     (Input_A =>
        (((-21.10,-22.50), ( 53.50,-50.50), (-34.50,127.50), (  7.50,  0.50)),
         (( -0.46, -7.78), ( -3.50,-37.50), (-15.50, 58.50), (-10.50, -1.50)),
         ((  4.30, -5.50), ( 39.70,-17.10), (-68.50, 12.50), ( -7.50, -3.50)),
         ((  5.50,  4.40), ( 14.40, 43.30), (-32.50,-46.00), (-19.00,-32.50))),
      Input_B =>
        (((  1.00, -5.00), (  1.60,  1.20), ( -3.00,  0.00), (  0.00, -1.00)),
         ((  0.80, -0.60), (  3.00, -5.00), ( -4.00,  3.00), ( -2.40, -3.20)),
         ((  1.00,  0.00), (  2.40,  1.80), ( -4.00, -5.00), (  0.00, -3.00)),
         ((  0.00,  1.00), ( -1.80,  2.40), (  0.00, -4.00), (  4.00, -5.00))),
      Expected_Alphas =>
        (( 3.0000E+00,-9.0000E+00),
         ( 2.0000E+00,-5.0000E+00),
         ( 3.0000E+00,-1.0000E-00),
         ( 4.0000E+00,-5.0000E+00)),
      Expected_Betas => (1 .. 0 => (0.0, 0.0)),
      Expected_Eigenvectors =>
        (Double_Tests.Transpose
           ((((-8.2377E-01,-1.7623E-01), (-1.5295E-01, 7.0655E-02),
              (-7.0655E-02,-1.5295E-01), ( 1.5295E-01,-7.0655E-02)),
             (( 6.3974E-01, 3.6026E-01), ( 4.1597E-03,-5.4650E-04),
              ( 4.0212E-02, 2.2645E-02), (-2.2645E-02, 4.0212E-02)),
             (( 9.7754E-01, 2.2465E-02), ( 1.5910E-01,-1.1371E-01),
              ( 1.2090E-01,-1.5371E-01), ( 1.5371E-01, 1.2090E-01)),
             ((-9.0623E-01, 9.3766E-02), (-7.4303E-03, 6.8750E-03),
              ( 3.0208E-02,-3.1255E-03), (-1.4586E-02,-1.4097E-01))))),
      Limit => 1.0e-6,
      Additional_Naming => "NAG ZGGEV example");

   function Suite return AUnit.Test_Suites.Access_Test_Suite
   is
      Result : constant AUnit.Test_Suites.Access_Test_Suite
        := new AUnit.Test_Suites.Test_Suite;
   begin
      AUnit.Test_Suites.Add_Test (Result, Single_Impl.Suite);
      AUnit.Test_Suites.Add_Test (Result, Double_Impl_NAG.Suite);
      --  AUnit.Test_Suites.Add_Test (Result, Extended_Impl.Suite);
      return Result;
   end Suite;

end Tests.Complex_Generalized_Eigenvalues;
