import "ProximityMatrix.m": ProximityMatrixImpl,
                            ProximityMatrixBranch,
                            MultiplicityVectorBranch,
                            CoefficientsVectorBranch;
import "IntegralClosure.m": IntegralClosureIrreducible,
                            Unloading, ProductIdeals,
                            ClusterFactorization, Curvettes;
import "BasePoints.m": ExpandWeightedCluster;
import "SemiGroup.m": TailExponentSeries;

FiltrationImpl := function(s, f, e, M)
  // Compute an upper bound for the necessary points.
  KK := (e*Transpose(e))[1][1]; N := Max(Ncols(e) + M - KK, Ncols(e));
  // Get the proximity matrix with all the necessary points.
  s := PuiseuxExpansionExpandReduced(s, f: Terms := M - KK - 1)[1];
  P := ProximityMatrixBranch(s, N); Pt := Transpose(P); Pt_inv := Pt^-1;
  e := MultiplicityVectorBranch(s, N); c := CoefficientsVectorBranch(s, N);

  // Compute the curvettes of the curve.
  Q<x, y> := LocalPolynomialRing(Parent(c[1][2]), 2, "lglex");
  Cv := Curvettes(P, e*Pt_inv, c, Q);
  // Compute the maximal ideal values.
  max := ZeroMatrix(IntegerRing(), 1, N); max[1][1] := 1; max := max*Pt_inv;

  // Construct the i-th cluster.
  ei := ZeroMatrix(IntegerRing(), 1, N); m_i := 0; H := [];
  while m_i lt M do
    // Get the last points with multiplicity zero.
    I := [i : i in [1..N] | ei[1][i] eq 0][1];
    ei[1][I] := 1; vi := ei*Pt_inv;
    // Unload K_i to get a strictly consistent cluster.
    vi := Unloading(P, vi); ei := vi*Pt;

    // Compute generators for the complete ideal H_i.
    Hi := [IntegralClosureIrreducible(P, P*Transpose(v_j), v_j, Cv, max, Q) :
      v_j in ClusterFactorization(P, vi)];
    Hi := [g[1] : g in ProductIdeals(Hi) |
      &or[g[2][1][i] lt (vi + max)[1][i] : i in [1..N]]];

    // Fill the gaps in the filtration.
    KK_i := &+[e[i] * ei[1][i] : i in [1..N]]; // Intersection [K, K_i]
    H cat:= [Hi]; m_i := KK_i;
  end while; return H;
end function;

// Helper funcition
ConvertToIdeal := func<I, Q | [&*[g[1]^g[2] : g in f] : f in I]>;

intrinsic Filtration(f::RngMPolLocElt, n::RngIntElt : Ideal := true) -> []
{ Returns a filtration by complete ideals of an irreducible
  plane curve up to autointersection n }
require n ge 0: "Second argument must be a non-negative integer";

  Q := Parent(f); S := PuiseuxExpansion(f: Polynomial := true);
  if #S gt 1 or S[1][2] gt 1 then error "the curve must be irreducible"; end if;
  s := S[1][1]; f := S[1][3]; _, e, _ := ProximityMatrixImpl([<s, 1>]);
  KK := e[1]*Transpose(e[1]); // Curve auto-intersection.

  F := FiltrationImpl(s, f, e[1], n eq 0 select KK[1][1] else n);
  if Ideal eq true then return [ConvertToIdeal(I, Q) : I in F];
  else return F; end if;
end intrinsic;

TjurinaFiltrationImpl := function(S, f)
  // Get the proximity matrix with all the necessary points.
  P, E, C := ProximityMatrixImpl(S); N := NumberOfColumns(P);
  Pt := Transpose(P); Pt_inv := Pt^-1; R := Parent(f);
  // The Tjurina ideal & its standard basis.
  J := JacobianIdeal(f) + ideal<R | f>; J := ideal<R | StandardBasis(J)>;

  // Compute the curvettes of the curve.
  A := Parent(C[1][1][2]); Q := LocalPolynomialRing(A, 2, "lglex");
  vi := E[1]*Pt_inv; Cv := Curvettes(P, vi, C[1], Q); ZZ := IntegerRing();
  // Add the curve itself as a curvette.
  Cvf := <[<Q!f, 1>], vi, E[1]>; Cv cat:= [Cvf];
  // Compute the maximal ideal values.
  max := ZeroMatrix(ZZ, 1, N); max[1][1] := 1; max := max*Pt_inv;

  // Construct the i-th cluster.
  ei := ZeroMatrix(ZZ, 1, N); JJ := []; Hi := ideal<R | 1>; Ji := Hi meet J;
  while Hi ne Ji do
    // Enlarge, if necessary, the cluster with one point on the curve.
    I := [i : i in [1..N] | ei[1][i] eq 0];
    if #I eq 0 then
      ExpandWeightedCluster(~P, ~E, ~C, ~S, -1); N := N + 1; P[N][N - 1] := -1;
      E[1][1][N] := 1; ei := E[1]; Pt := Transpose(P); Pt_inv := Pt^-1;
      // Expand (i.e. blow-up an extra point) the maximal ideal.
      max := ZeroMatrix(ZZ, 1, N); max[1][1] := 1; max := max*Pt_inv;

      newCv := []; // Expand (i.e. blow-up an extra points) the curvettes.
      for i in [1..#Cv] do
        Ei := InsertBlock(ZeroMatrix(ZZ, 1, N), Cv[i][3], 1, 1);
        if i eq #Cv then Ei[1][N] := 1; end if; // The last curvette is f.
        newCv cat:= [<Cv[i][1], Ei*Pt_inv, Ei>];
      end for; Cv := newCv;
    else ei[1][I[1]] := 1; end if;

    // Unload K_i to get a strictly consistent cluster.
    vi := ei*Pt^-1; vi := Unloading(P, vi); ei := vi*Pt;

    // Compute generators for the complete ideal H_i.
    Hi := [IntegralClosureIrreducible(P, P*Transpose(v_j), v_j, Cv, max, Q)
      : v_j in ClusterFactorization(P, vi)];
    Hi := [g[1] : g in ProductIdeals(Hi) | &or[g[2][1][i] lt
      (vi + max)[1][i] : i in [1..N]]];
    Hi := ideal<R | ConvertToIdeal(Hi, R)>; Ji := Hi meet J;

    // Only keep the traces ideals that are strictly contained in the Jacobian.
    if Ji ne J then JJ cat:= [Ji]; end if;
  end while; return [J] cat JJ;
end function;

intrinsic TjurinaFiltration(f::RngMPolLocElt) -> []
{ Returns an adapted filtration of the Tjurinna ideal of an irreducible
  plane curve }

  Q := Parent(f); S := PuiseuxExpansion(f: Polynomial := true);
  if #S gt 1 or S[1][2] gt 1 then error "the curve must be irreducible"; end if;
  return TjurinaFiltrationImpl(S, f);
end intrinsic;
