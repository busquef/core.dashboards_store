{#
Dashboards Store - Helping students, one dashboard at a time.
Copyright (C) 2023  Sciance Inc.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
#}
{{
    config(
        alias="report_res_bilan_mat_eco",
    )
}}


with
    cal as (
        select
            code_perm,
            population,
            annee,
            code_ecole,
            eco,
            genre,
            plan_interv_ehdaa,
            ordre_ens,
            mat,
            des_matiere,
            case when res_num_mat < 60 then 1 else 0 end as tx_echec,
            case when res_num_mat > 59 then 1 else 0 end as tx_reussite,
            case
                when
                    res_num_mat > 59
                    and res_num_mat
                    < {{ var("res_scolaires", {"threshold": 70})["threshold"] }}
                then 1
                else 0
            end as tx_risque,
            case
                when
                    res_num_mat
                    >= {{ var("res_scolaires", {"threshold": 70})["threshold"] }}
                then 1
                else 0
            end as tx_maitrise,
            res_num_mat
        from {{ ref("fact_res_bilan_mat") }}
        inner join {{ ref("resco_dim_matiere") }} as dim on dim.cod_matiere = mat  -- Only keep the tracked courses
        where annee between {{ get_current_year() }} - 4 and {{ get_current_year() }}
    ),
    agg as (
        select
            population,
            annee,
            code_ecole,
            eco,
            ordre_ens,
            mat,
            genre,
            plan_interv_ehdaa,
            des_matiere,
            count(res_num_mat) over (
                partition by
                    population,
                    annee,
                    ordre_ens,
                    mat,
                    code_ecole,
                    des_matiere,
                    genre,
                    plan_interv_ehdaa
            ) as n_obs_f,
            count(res_num_mat) over (
                partition by annee, mat, code_ecole, population
            ) as n_obs_g,
            sum(try_cast(tx_reussite as float)) over (
                partition by annee, mat, code_ecole, population
            ) as n_reussite_g,
            sum(try_cast(tx_reussite as float)) over (
                partition by
                    population,
                    annee,
                    ordre_ens,
                    code_ecole,
                    mat,
                    des_matiere,
                    genre,
                    plan_interv_ehdaa
            ) as n_reussite_f,
            sum(try_cast(tx_risque as float)) over (
                partition by annee, code_ecole, mat, population
            ) as n_risque_g,
            sum(try_cast(tx_risque as float)) over (
                partition by
                    population,
                    annee,
                    ordre_ens,
                    code_ecole,
                    mat,
                    des_matiere,
                    genre,
                    plan_interv_ehdaa
            ) as n_risque_f,
            sum(try_cast(tx_echec as float)) over (
                partition by annee, code_ecole, mat, population
            ) as n_echec_g,
            sum(try_cast(tx_echec as float)) over (
                partition by
                    population,
                    annee,
                    code_ecole,
                    ordre_ens,
                    mat,
                    des_matiere,
                    genre,
                    plan_interv_ehdaa
            ) as n_echec_f,
            sum(try_cast(tx_maitrise as float)) over (
                partition by annee, code_ecole, mat, population
            ) as n_maitrise_g,
            sum(try_cast(tx_maitrise as float)) over (
                partition by
                    population,
                    annee,
                    code_ecole,
                    ordre_ens,
                    mat,
                    des_matiere,
                    genre,
                    plan_interv_ehdaa
            ) as n_maitrise_f,
            avg(try_cast(res_num_mat as decimal(5, 2))) over (
                partition by annee, code_ecole, mat, population
            ) as resultat_avg_g,
            avg(try_cast(res_num_mat as decimal(5, 2))) over (
                partition by
                    population,
                    annee,
                    code_ecole,
                    ordre_ens,
                    code_ecole,
                    mat,
                    des_matiere,
                    genre,
                    plan_interv_ehdaa
            ) as resultat_avg_f
        from cal
    -- Add the statistis
    ),

    totaux as (
        select
            population,
            annee,
            ordre_ens,
            mat,
            code_ecole,
            eco,
            genre,
            plan_interv_ehdaa,
            des_matiere,
            max(n_obs_f) as n_obs_f,
            max(n_obs_g) as n_obs_g,
            max(n_reussite_f) as n_reussite_f,
            max(n_reussite_g) as n_reussite_g,
            max(n_risque_f) as n_risque_f,
            max(n_risque_g) as n_risque_g,
            max(n_echec_f) as n_echec_f,
            max(n_echec_g) as n_echec_g,
            max(n_maitrise_f) as n_maitrise_f,
            max(n_maitrise_g) as n_maitrise_g,
            max(resultat_avg_f) as resultat_avg_f,
            max(resultat_avg_g) as resultat_avg_g
        from agg
        group by
            population,
            annee,
            ordre_ens,
            mat,
            des_matiere,
            genre,
            plan_interv_ehdaa,
            code_ecole,
            eco
    ),

    stats as (
        select
            {{
                dbt_utils.generate_surrogate_key(
                    [
                        "population",
                        "annee",
                        "mat",
                        "genre",
                        "plan_interv_ehdaa",
                        "des_matiere",
                    ]
                )
            }} as id_mat_year,
            population,
            annee,
            ordre_ens,
            genre,
            plan_interv_ehdaa,
            mat,
            des_matiere,
            code_ecole,
            eco,
            n_obs_f,
            n_obs_g,
            resultat_avg_f,
            resultat_avg_g,
            n_reussite_f,
            n_reussite_f / n_obs_f as percent_of_success_f,
            n_reussite_g,
            n_reussite_g / n_obs_g as percent_of_success_g,
            n_echec_f,
            n_echec_f / n_obs_f as percent_of_echec_f,
            n_echec_g,
            n_echec_g / n_obs_g as percent_of_echec_g,
            n_risque_f,
            n_risque_f / n_obs_f as percent_of_risque_f,
            n_risque_g,
            n_risque_g / n_obs_g as percent_of_risque_g,
            n_maitrise_f,
            n_maitrise_f / n_obs_f as percent_of_maitrise_f,
            n_maitrise_g,
            n_maitrise_g / n_obs_g as percent_of_maitrise_g
        from totaux
    ),
    ecart as (
        select
            stats.*,
            (stats.percent_of_success_f)
            - (stcss.percent_of_success_f) as ecart_percent_of_success_f,
            (stats.percent_of_success_g)
            - (stcss.percent_of_success_g) as ecart_percent_of_success_g,
            (stats.percent_of_risque_f)
            - (stcss.percent_of_risque_f) as ecart_percent_of_risque_f,
            (stats.percent_of_risque_g)
            - (stcss.percent_of_risque_g) as ecart_percent_of_risque_g,
            (stats.percent_of_maitrise_f)
            - (stcss.percent_of_maitrise_f) as ecart_percent_of_maitrise_f,
            (stats.percent_of_maitrise_g)
            - (stcss.percent_of_maitrise_g) as ecart_percent_of_maitrise_g,
            (stats.resultat_avg_f) - (stcss.resultat_avg_f) as ecart_resultat_avg_f,
            (stats.resultat_avg_g) - (stcss.resultat_avg_g) as ecart_resultat_avg_g
        from stats
        left join
            {{ ref("resco_report_res_bilan_mat_css") }} as stcss
            on stats.id_mat_year = stcss.id_mat_year
    )
select
    -- Dimensions
    id_mat_year,
    population,
    annee,
    ordre_ens,
    plan_interv_ehdaa,
    eco,
    code_ecole,
    mat,
    genre,
    des_matiere,
    -- Metrics
    n_obs_f,
    n_obs_g,
    resultat_avg_f,
    resultat_avg_g,
    n_reussite_f,
    percent_of_success_f,
    n_reussite_g,
    percent_of_success_g,
    n_echec_f,
    percent_of_echec_f,
    n_echec_g,
    percent_of_echec_g,
    n_risque_f,
    percent_of_risque_f,
    n_risque_g,
    percent_of_risque_g,
    n_maitrise_f,
    percent_of_maitrise_f,
    n_maitrise_g,
    percent_of_maitrise_g
    ecart_percent_of_success_f,
    ecart_percent_of_success_g,
    ecart_percent_of_risque_f,
    ecart_percent_of_risque_g,
    ecart_percent_of_maitrise_f,
    ecart_percent_of_maitrise_g,
    ecart_resultat_avg_f,
    ecart_resultat_avg_g
from ecart
