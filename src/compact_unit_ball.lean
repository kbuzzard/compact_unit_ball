-- don't need to import things which other files import
import topology.sequences
import analysis.normed_space.finite_dimension

-- type class inference in Lean 3 has been pushed too far by mathematicians. 
-- Lean 4 should fix these issues.
local attribute [instance, priority 10000] mul_action.to_has_scalar distrib_mul_action.to_mul_action
semimodule.to_distrib_mul_action module.to_semimodule vector_space.to_module normed_space.to_vector_space
ring.to_monoid normed_ring.to_ring normed_field.to_normed_ring add_group.to_add_monoid
add_comm_group.to_add_group normed_group.to_add_comm_group ring.to_semiring add_comm_group.to_add_comm_monoid
normed_field.to_discrete_field

-- see above.
set_option class.instance_max_depth 100
noncomputable theory
open_locale classical

open metric set submodule

variables
{V : Type} [normed_group V] [normed_space ℝ V]

-- "by X" is the same as "begin X end"
lemma two_positive : (2 : ℝ) > 0 := by norm_num

lemma half_positive : (1/2 : ℝ) > 0 := by norm_num

-- move hyp and v before the colon to save on intros
lemma ball_span_ash {A : set V} (hyp : ∀ v : V, norm v ≤ 1 → v ∈ submodule.span ℝ A) (v : V) :
  v ∈ submodule.span ℝ A :=
begin
  by_cases hv : v = 0,
  { rw hv, exact zero_mem _},
-- let's write the proof backwards.
  rw [←one_smul ℝ v, ←@mul_inv_cancel _ _ (∥v∥) _, mul_smul],
  { refine smul_mem _ _ (hyp _ _),
    rw [norm_smul, real.norm_eq_abs],--, abs_of_nonneg (norm_nonneg _)],
    rw abs_of_nonneg,
      exact le_of_eq (inv_mul_cancel $ mt (norm_eq_zero _).1 hv),
    exact inv_nonneg.2 (norm_nonneg _),
    },
  exact mt (norm_eq_zero _).1 hv,
end

lemma ball_span {A : set V} : (∀ v : V, v ∈ (closed_ball 0 1 : set V) → v ∈ submodule.span ℝ A) 
→ ∀ v : V, v ∈ submodule.span ℝ A :=
begin
  intro H,
  have hyp : ∀ v : V, norm v ≤ 1 → v ∈ submodule.span ℝ A,
  intros v hv,
  rw <- dist_zero_right at hv,
  exact H v hv,
  exact ball_span_ash hyp,
end


theorem finite_dimensional_span_of_finite {V : Type} {A : set V} [normed_group V] [normed_space ℝ V] (hA : finite A) :
  finite_dimensional ℝ ↥(submodule.span ℝ A) :=
begin
  apply is_noetherian_of_fg_of_noetherian,
  exact submodule.fg_def.2 ⟨A, hA, rfl⟩,
end

lemma finite_span_seq_closed (A : set V) : finite A → is_seq_closed (↑(submodule.span ℝ A) : set V) :=
begin
  intro h_fin,
  apply is_seq_closed_of_is_closed,
  haveI : finite_dimensional ℝ (submodule.span ℝ A) := finite_dimensional_span_of_finite h_fin,
  exact submodule.closed_of_finite_dimensional _,
end

--turns cover into a choice function
lemma cover_to_func (A X : set V) (hX : X ⊆ (⋃a ∈ A, ball a (0.5 : real)))
  (a : V) (ha : a ∈ A) :
  ∃(f : V → V), ∀x, f x ∈ A ∧ (x ∈ X → x ∈ ball (f x) (0.5 : real)) :=
begin
  classical,
  have : ∀(x : V), ∃a, a ∈ A ∧ (x ∈ X → x ∈ ball a (0.5 : real)) :=
  begin
    assume x,
    by_cases h : x ∈ X,
    { simpa [h] using hX h },
    { exact ⟨a, ha, by simp [h]⟩ }
  end,
  choose f hf using this,
  exact ⟨f, λx, hf x⟩
end

lemma compact_choice_func (hc : compact (closed_ball 0 1 : set V)) :
  ∃ A : set V, A ⊆ (closed_ball 0 1 : set V) ∧ finite A ∧
  ∃ f : V → V, ∀ x : V, f x ∈ A ∧ (x ∈ (closed_ball 0 1 : set V) 
  → x ∈ ball (f x) (0.5 : real)) :=
begin
  let B : set V := closed_ball 0 1,
  have cover : B ⊆ ⋃ a ∈ B, ball a (0.5 : real),
    {
        intros x hx,
        simp,
        use x,
        rw dist_self,
        simp,
        split,
        simp at hx,
        exact hx,
        linarith,
    },
    obtain ⟨A, A_sub, A_fin, HcoverA⟩ :
    ∃ A ⊆ B, finite A ∧ B ⊆ ⋃ a ∈ A, ball a (0.5 : real) :=
        compact_elim_finite_subcover_image hc (by simp[is_open_ball]) cover,
    
    -- need that A is non-empty to construct a choice function!
    have x_in : (0 : V) ∈ B,
    simp, 
    linarith,

    obtain ⟨a, a_in, ha⟩ : ∃ a ∈ A, dist (0 : V) a < (0.5 : real),
      by simpa using HcoverA x_in,
    
    have hfunc := cover_to_func A B HcoverA a a_in,

    existsi A,
    split,
    exact A_sub,
    split,
    exact A_fin,
    exact hfunc,
end

def aux_seq (v : V) (f : V → V) : ℕ → V
| 0 := v
| (n + 1) :=  (2 : ℝ) • (aux_seq n - f (aux_seq n))

def partial_sum (f : ℕ → V) : ℕ → V
| 0 := f 0
| (n + 1) := f (n + 1) + partial_sum n

def approx_seq (v : V) (f : V → V) : ℕ → V :=
  partial_sum (λ n : ℕ, (1/2 : ℝ)^n • f(aux_seq v f n))

lemma bound_power_two_convergence (w : ℕ → V) {v : V}
  (h : ∀ n : ℕ, norm (v - w n) ≤ (0.5 : ℝ)^(n + 1)) :
  filter.tendsto w filter.at_top (nhds v) :=
begin
  have H : ∀ n : ℕ, norm (w n - v) ≤ (0.5 : ℝ)^n,
  intro n,
  rw <- dist_eq_norm,
  rw dist_comm,
  rw dist_eq_norm,
  apply le_trans,
  exact h n,
  rw pow_succ,
  have h1 : (0.5 : ℝ) * (0.5 : ℝ)^n ≤ 1 * (0.5 : ℝ)^n,
  rw mul_le_mul_right,
  linarith,
  apply pow_pos,
  exact half_positive,
  rw one_mul at h1,
  exact h1,

  rw tendsto_iff_norm_tendsto_zero,
  apply squeeze_zero,
  intro t,
  exact norm_nonneg (w t - v),
  exact H,
  apply tendsto_pow_at_top_nhds_0_of_lt_1,
  rw le_iff_eq_or_lt,
  right,
  exact half_positive,
  linarith,  
end

lemma approx_in_span (A : set V) (v : V) (f : V → V) 
  (hf : ∀ x : V, f x ∈ A): 
  ∀ n : ℕ, approx_seq v f n ∈ submodule.span ℝ A :=
begin
  let w := approx_seq v f,
  have hw : w = approx_seq v f,
  refl,
  intro n,
  rw submodule.mem_span,
  intros p hp,
  induction n with n hn,
  {
    have h1 : w 0 = (1/2 : ℝ)^0 • f(v), refl,
    simp at h1,
    rw <- hw,
    rw h1,
    have h2 : f v ∈ A := hf v,
    exact hp h2,
  },{
    have h1 : w (n+1) = (1/2 : ℝ)^(n+1) • f(aux_seq v f (n+1)) + w(n), 
    refl,
    rw <- hw,
    rw h1,
    have h2 := hp (hf (aux_seq v f (n+1))),
    have h3 := submodule.smul_mem p ((1/2 : ℝ)^(n+1)) h2,
    apply submodule.add_mem p,
    exact h3,
    exact hn,
  },
end

lemma limit_in_span {S : set V} (hseq : is_seq_closed S) 
  {w : ℕ → V} (hw : ∀ n : ℕ, w n ∈ S) 
  {v : V} (hlim : filter.tendsto w filter.at_top (nhds v : filter V)) :
  v ∈ S :=
begin
  exact mem_of_is_seq_closed hseq hw hlim,
end

--set_option profiler true
theorem compact_unit_ball_implies_finite_dim : 
    compact (closed_ball 0 1 : set V) → vector_space.dim ℝ V < cardinal.omega :=
begin
    intro Hcomp,
    obtain ⟨A, A_sub, A_fin, Hexistsf⟩ := compact_choice_func Hcomp,
    obtain ⟨f, hf⟩ := Hexistsf,

    let B : set V := closed_ball 0 1,

    -- suffices to show B is spanned by A
    rw <- finite_dimensional.finite_dimensional_iff_dim_lt_omega,
    apply finite_dimensional.of_fg,

    rw submodule.fg_def,
    existsi A,
    split,
    exact A_fin,
    rw submodule.eq_top_iff',
    apply ball_span,

    intros v hv,
    let u : ℕ → V := aux_seq v f,
    let w : ℕ → V := partial_sum (λ x : ℕ, (0.5 : ℝ)^x • f(u(x))),

    -- want to show that w n in span A and  w n -> v as n -> infty

    have hw : ∀ n, w n ∈ submodule.span ℝ A,
    {
      have hf' : ∀ x : V, f x ∈ A,
      intro x, 
      exact (hf x).1,
      exact approx_in_span A v f hf',
    },

    -- this is just some algebraic manipulation
    have hdist : ∀ n : ℕ, v - w n = (0.5 : real)^(n+1) • u (n+1),
    {
      intro n,
      induction n with n hn,
      {
        have h1 : w 0 = (0.5 : real)^0 • f(v), refl,
        rw zero_add,
        rw pow_one,
        rw pow_zero at h1,
        rw one_smul at h1,
        rw h1,
        have h2 : u 1 = (2: ℝ) • (v - f(v)), refl,
        rw h2,
        rw smul_smul,
        rw one_div_mul_cancel,
        rw one_smul,
        exact two_ne_zero',
      }, {
        have h1 : w (n+1) = (0.5 : real)^(n+1) • f(u (n+1)) + w(n), refl,
        have h2 : u (n+2) = (2 : ℝ) • (u (n+1) - f (u (n+1))), refl,
        rw h2,
        rw pow_succ,
        rw smul_smul,
        rw mul_comm,
        rw <- mul_assoc,
        rw mul_one_div_cancel,
        rw one_mul,
        rw smul_sub,
        rw <- hn,
        rw h1,
        rw add_comm _ (w n),
        rw sub_sub v (w n) _,
        exact two_ne_zero',
      },
    },

    -- main bound for convergence using the expression hdist
    have hbound : ∀ n : ℕ, norm (v - w n) ≤ (0.5 : ℝ)^(n+1),
    {
      intro n,
      rw hdist n,
      rw norm_smul,
      rw real.norm_eq_abs,
      rw abs_of_nonneg,
      have hu : u(n+1) = (2 : ℝ) • (u(n) - f(u(n))), refl,
      rw hu,
      have husmall : norm (u n) ≤ 1,
      {
        induction n with n hn,
        have h0 : u 0 = v, refl,
        rw h0,
        rw <- dist_zero_right,
        exact hv,

        have hu' : u(n + 1) = (2 : ℝ) • (u(n) - f(u(n))), refl,
        rw hu',
        have h2 := (hf (u n)).2,
        rw norm_smul,
        rw real.norm_eq_abs,
        rw <- dist_eq_norm,
        rw abs_of_nonneg,
        have h3 := hn hu',
        rw <- dist_zero_right at h3,
        have h4 : dist (u n) (f (u n)) < 1/2,
        exact h2 h3,
        rw le_iff_eq_or_lt,
        right,
        rw <- mul_lt_mul_left two_positive at h4,  
        rw mul_one_div_cancel at h4,
        exact h4,   
        exact two_ne_zero',
        linarith,
      },
      have h2 : 0 < (1/2 : ℝ) := half_positive,
      have h1 : 0 < (1/2 : ℝ)^(n+1),
      exact pow_pos h2 (n+1),
      have h3 : (1/2 : ℝ)^(n+1) * norm ((2:ℝ) • (u n - f(u n))) ≤ (1/2 : ℝ)^(n+1) * 1 → 
        (1/2 : ℝ)^(n+1) * norm ((2:ℝ) • (u n - f(u n))) ≤ (1/2 : ℝ)^(n+1),
      intro h,
      rw mul_one at h,
      exact h,
      apply h3,
      rw mul_le_mul_left h1,
      rw norm_smul,
      rw <- dist_zero_right at husmall,
      have h4 := (hf (u n)).2 husmall,
      rw <- dist_eq_norm,
      rw real.norm_eq_abs,
      rw abs_of_nonneg,
      rw <- mul_le_mul_left h2,
      rw <- mul_assoc,
      rw mul_one,
      rw one_div_mul_cancel,
      rw one_mul,
      rw le_iff_eq_or_lt,
      right,
      exact h4,
      exact two_ne_zero',
      linarith,
      rw ge_iff_le,
      rw le_iff_eq_or_lt,
      right,
      exact pow_pos half_positive (n+1),
    },

    have hlim : filter.tendsto w filter.at_top (nhds v : filter V)
    := bound_power_two_convergence w hbound,
    
    let S : set V := ↑(submodule.span ℝ A),
    have hspan_closed : is_seq_closed S := finite_span_seq_closed A A_fin,

    have hw' : ∀ n, w n ∈ S,
    exact hw,

    have hinS: v ∈ S,
    exact limit_in_span hspan_closed hw' hlim,
    exact hinS,
end
