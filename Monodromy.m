
JacobianMembership := function(f)
  Jstd := JacobianIdeal(f); kappa := 1; n := Rank(Parent(f));
  while NormalForm(f^kappa, Jstd) ne 0 do kappa +:= 1; end while;

  J := IdealWithFixedBasis(Basis(JacobianIdeal(f)));
  Xi := Coordinates(J, f^kappa);

  return kappa, Xi;
end function;

// Computes the inverse of a unit in a local polynomial ring. It uses the
// standard algorithm to divide univariate series (see, for instance, Knuth,
// TAOCP vol. 2) indentifying [z^n] with the n-th homogeneous term.
Inverse := function(u, n)
  // Returns the k-th homogeneous part of a polynomial f.
  Part := func<f, k | &+[Parent(f) | m : m in Terms(f) | TotalDegree(m) eq k]>;

  u0 := LeadingTerm(u); v := 1/u0;
  for i in [1..n] do
    v -:= &+[(Part(v, k)*Part(u, i - k))/u0 : k in [0..i-1]];
  end for; return v;
end function;

//
BasisKJetsH2 := function(f, K, mu)
  R := Parent(f); g := Rank(R); M := ideal<R | [R.i : i in [1..g]]>;
  n := Multiplicity(f); N := n; codimD := 0;

  while codimD lt K*mu do
    // Compute { f^K z^a, |a| < N - K*n } a CC basis of f^k Omega^n
    //B1 := apply(monomialBasis(N - K*n, R), m -> f^K*m);
    RM1 := R/M^Max([0, N - K*n]); F1 := hom<RM1 -> R | [R.i : i in [1..g]]>;
    B := [f^K*m : m in F1(MonomialBasis(RM1))];
    // Compute {a_i*z^a / z_i*f_j - a_j*z^a / z_j*f_i, |a| < N - n + 2}
    // a CC basis of df \wedge d(Omega^{n-2})
    RM2 := R/M^Max([0, N - n + 2]); F2 := hom<RM2 -> R | [R.i : i in [1..g]]>;
    B cat:= [Derivative(m, i)*Derivative(f, j) -
             Derivative(m, j)*Derivative(f, i)
             : m in F2(MonomialBasis(RM2)), i in [1..g], j in [1..g] | i lt j];
    // Compute the N-jets of B as a vector space over CC.
    RM := R/M^N; V, G := VectorSpace(RM); // F *might* be superflous after bug fix OR ChangeUniverse(~B, RM). <---------- TODO
    F := hom<R -> RM | [RM.i : i in [1..g]]>; WG := (F*G)(B); W := sub<V | WG>;
    D := Binomial(N + g - 1, g); codimD := D - Dimension(W); N := N + 1;
  end while; return N - 1, W, WG, G;
end function;

// Given a C{f}-basis of H2, computes its image via (t^kappa nabla) modulo N,
// since the image are arbitrary series.
NablaN := function(f, kappa, Xi, u, H2, N);
  uinv := Inverse(u, N); kfk := kappa*f^(kappa - 1); g := Rank(Parent(f));
  return [&+[Derivative(uinv*Xi[i]*e, i) : i in [1..g]] - kfk*e : e in H2];
end function;

// Returns the K-jets (mod t^k) of the de residue matrix on the Gauss-Manin
// connection on the lattice H2.
ConnectionMatrix := function(f, kappa, Xi, u, K, H2, S)
  mu := #H2; N, _, WG, G := BasisKJetsH2(f, K, mu); // K
  nablaH2 := NablaN(f, kappa, Xi, u, H2, N); // N
  kJetsH2 := [f^i*e : e in H2, i in [0..K - 1]]; // K

  R := Parent(f); g := Rank(R); M := ideal<R | [R.i : i in [1..g]]>; // ????
  RM := R/M^N; F := hom<R -> RM | [RM.i : i in [1..g]]>; // F *might* be superflous after bug fix OR ChangeUniverse(~B, RM). <---------- TODO

  VW := Matrix((F*G)(kJetsH2) cat WG); E, T := EchelonForm(Transpose(VW));
  VnablaH2 := Matrix((F*G)(nablaH2)); C := VnablaH2*Transpose(T);

  M := ZeroMatrix(S, mu, mu); t := S.1;
  for k in [0..K - 1] do
    M +:= ChangeRing(Submatrix(C, 1, k*mu + 1, mu, mu), S)*t^k;
  end for; return M;
end function;

intrinsic Monodromy(f::RngMPolLocElt) -> []
{ Computes the matrix of the monodromy action in the cohomology of the
  Milnor fiber using an algorithm by Brieskorn }
  mu := MilnorNumber(f);
  require mu ne Infinity(): "Argument must be an isolated singularity.";

  //---------------------------------------------------------------------------
  //-------------------- STEP 1: Find f^kappa \in J(f) ------------------------
  //---------------------------------------------------------------------------

  R := Parent(f); g := Rank(R); x := R.1; y := R.2;
  kappa, _ := JacobianMembership(f);
  Xi := [-(2/3)*x*y^6+(1/6)*x^7+(9/2)*x^3*y^8-(3/2)*x^9*y^2,
         (1/2)*x^2*y^3+(1/6)*y^7+(5/6)*x^6*y-4*x^4*y^5-(3/2)*x^2*y^9-(15/2)*x^8*y^3];
  u := ExactQuotient(Derivative(f, 1)*Xi[1] + Derivative(f, 2)*Xi[2], f^kappa);

  //---------------------------------------------------------------------------
  //--------------- STEP 2: Compute a C{f}-basis of H2 ------------------------
  //---------------------------------------------------------------------------

  // Compute a C-basis of I_k = f^k Omega^n + df \wedge dOmega^{n/1} modulo
  // a power of a maximal ideal (m^N) such that m^N \subset t^k H^2. (k = 1)
  N, W, _, G := BasisKJetsH2(f, 1, mu);
  // Compute a C-basis of Omega^n / m^N.
  RM := Domain(G); V := Codomain(G); F := hom<RM -> R | [R.i : i in [1..g]]>;
  // A C-basis of (Omega^n/m^N) / (I_1/m^N) = H2/tH2 is a C{f}-basis of H2/tH2.
  MB := Setseq(F(MonomialBasis(RM)));
  H2 := [Polynomial(Eltseq(v), MB) : v in Basis(Complement(V, W))];

  //---------------------------------------------------------------------------
  //--------------- STEP 3: Compute the saturated lattice ---------------------
  //---------------------------------------------------------------------------

  S<t> := LocalPolynomialRing(Rationals(), 1); E := EModule(S, mu);
  Diff := hom<S -> S | x :-> Derivative(x, 1)>;
  Div := func<k | hom<S -> S | x :-> ExactQuotient(x, t^k)>>;
  // Iterate lattice until it stabilizes.
  U := t^((kappa - 1)*(mu - 1))*ScalarMatrix(mu, S!1); i := 1;
  repeat
    M := ConnectionMatrix(f, kappa, Xi, u, (kappa - 1)*i, H2, S);
    prevU := sub<E | RowSequence(U)>; i +:= 1;
    // U_i = U_{i-1} + td/dtU_{i-1} + M/t^(kappa-1)*U_{i-1}.
    U := VerticalJoin([U, t*ChangeRing(U, Diff), ChangeRing(U, Div(kappa - 1))*M]);
    U := Matrix(MinimalBasis(sub<E | Reverse(RowSequence(U))>));
  until sub<E | RowSequence(U)> eq prevU;
  ordU := Min([LeadingTotalDegree(e) : e in Eltseq(U) | e ne 0]);
  U := ChangeRing(U, Div(ordU));

  //---------------------------------------------------------------------------
  //--------------- STEP 4: Base change to the saturated lattice --------------
  //---------------------------------------------------------------------------

  // Compute the determinant of U s.t. det U = t^ordDetU * uDet.
  detU := Determinant(U); ordDetU := LeadingTotalDegree(detU);
  detU := ExactQuotient(detU, t^ordDetU);
  // Compute the adjoint matrix of U s.t. adj U = t^ordAdjU * adjU
  adjU := Adjoint(U);
  ordAdjU := Min([LeadingTotalDegree(e) : e in Eltseq(adjU) | e ne 0]);
  adjU := ChangeRing(adjU, Div(ordAdjU));
  // Get series with enough precision for the computation.
  alpha := kappa + ordDetU - ordAdjU; invUDet := Inverse(detU, alpha);
  M := ConnectionMatrix(f, kappa, Xi, u, alpha, H2, S);
  // Apply base change formula.
  M := ChangeRing(invUDet*(t^kappa * ChangeRing(U, Diff) + U*M)*adjU, Div(alpha - 1));
  return Matrix(Rationals(), mu, mu, [Evaluate(e, <0>) : e in Eltseq(M)]);
end intrinsic;