
#' @param refs Package names or references. See
#'   ['Package references'][pkg_refs] for the syntax.
#' @param ... Additional arguments, passed to
#'   [`pkg_deps$new()`](#method-new).
#'
#' @details
#' `new_pkg_deps()` creates a new object from the `pkg_deps` class.
#' The advantage of `new_pkg_deps()` compared to using the [pkg_deps]
#' constructor directly is that it avoids making pkgdepends a build time
#' dependency.
#'
#' @export
#' @rdname pkg_deps

new_pkg_deps <- function(refs, ...) {
  pkg_deps$new(refs, ...)
}

#' R6 class for package dependency lookup
#'
#' @description
#' Look up dependencies of R packages from various sources.
#'
#' @details
#' The usual steps to query package dependencies are:
#'
#' 1. Create a `pkg_deps` object with `new_pkg_deps()`.
#' 1. Resolve all possible dependencies with
#'    [`pkg_deps$resolve()`](#method-resolve).
#' 1. Solve the dependencies, to obtain a subset of all possible
#'    dependencies that can be installed together, with
#'    [`pkg_deps$solve()`](#method-solve).
#' 1. Call [`pkg_deps$get_solution()`](#method-get-solution) to list the
#'    result of the dependency solver.
#'
#' @export

pkg_deps <- R6::R6Class(
  "pkg_deps",
  public = list(

    #' @description
    #' Create a new `pkg_deps` object. Consider using `new_pkg_deps()`
    #' instead of calling the constructor directly.
    #'
    #' The returned object can be used to look up (recursive) dependencies
    #' of R packages from various sources. To perform the actual lookup,
    #' you'll need to call the [`resolve()`](#method-resolve) method.
    #' @param refs Package names or references. See
    #'   ['Package references'][pkg_refs] for the syntax.
    #' @param config Configuration options, a named list. See
    #'   ['Configuration'][pkg_config].
    #' @param remote_types Custom remote ref types, this is for advanced
    #'   use, and experimental currently.
    #'
    #' @return
    #'  A new `pkg_deps` object.
    #'
    #' @examples
    #' pd <- pkg_deps$new("r-lib/pkgdepends")
    #' pd

    initialize = function(refs, config = list(), remote_types = NULL) {
      private$library <- tempfile()
      dir.create(private$library)
      private$plan <- pkg_plan$new(
        refs,
        config,
        library = private$library,
        remote_types
      )
    },

    #' @description
    #' The package refs that were used to create the `pkg_deps` object.
    #'
    #' @return
    #' A character vector of package refs that were used to create the
    #' `pkg_deps` object.
    #'
    #' @examples
    #' pd <- new_pkg_deps(c("pak", "jsonlite"))
    #' pd$get_refs()

    get_refs = function() private$plan$get_refs(),

    #' @description
    #' Configuration options for the `pkg_deps` object. See
    #' ['Configuration'][pkg_config] for details.
    #'
    #' @return
    #' Named list. See ['Configuration'][pkg_config] for the configuration
    #' options.
    #'
    #' @examples
    #' pd <- new_pkg_deps("pak")
    #' pd$get_config()

    get_config = function() private$plan$get_config(),

    #' @description
    #' Resolve the dependencies of the specified package references. This
    #' usually means downloading metadata from CRAN and Bioconductor, unless
    #' already cached, and also from GitHub if GitHub refs were included,
    #' either directly or indirectly. See
    #' ['Dependency resolution'][pkg_resolution] for details.
    #'
    #'@return
    #' The `pkg_deps` object itself, invisibly.
    #'
    #' @examplesIf pkgdepends:::is_online()
    #' pd <- new_pkg_deps("pak")
    #' pd$resolve()
    #' pd$get_resolution()

    resolve = function() {
      private$plan$resolve()
      invisible(self)
    },

    #' @description
    #' The same as [`resolve()`](#method-resolve), but asynchronous.
    #' This method is for advanced use.
    #'
    #' @return
    #' A deferred value.

    async_resolve = function() private$plan$async_resolve(),

    #' @description
    #' Query the result of the dependency resolution. This method can be
    #' called after [`resolve()`](#method-resolve) has completed.
    #'
    #' @return
    #' A [pkg_resolution_result] object, which is also a tibble. See
    #' ['Dependency resolution'][pkg_resolution] for its columns.
    #'
    #' @examplesIf pkgdepends:::is_online()
    #' pd <- new_pkg_deps("r-lib/pkgdepends")
    #' pd$resolve()
    #' pd$get_resolution()

    get_resolution = function() private$plan$get_resolution(),

    #' @description
    #' Solve the package dependencies. Out of the resolved dependencies, it
    #' works out a set of packages, that can be installed together to
    #' create a functional installation. The set includes all directly
    #' specified packages, and all required (or suggested, depending on
    #' the configuration) packages as well. It includes every package at
    #' most once. See ['The dependency solver'][pkg_solution] for details.
    #'
    #' `solve()` calls [`resolve()`](#method-resolve) automatically, if it
    #' hasn't been called yet.
    #'
    #' @return
    #' The `pkg_deps` object itself, invisibly.
    #'
    #' @examplesIf pkgdepends:::is_online()
    #' pd <- new_pkg_deps("r-lib/pkgdepends")
    #' pd$resolve()
    #' pd$solve()
    #' pd$get_solution()

    solve = function() {
      private$plan$solve(policy = "lazy")
      invisible(self)
    },

    #' @description
    #' Returns the solution of the package dependencies.
    #' @return
    #' A [pkg_solution_result] object, which is a list. See
    #' [pkg_solution_result] for details.
    #'
    #' @examplesIf pkgdepends:::is_online()
    #' pd <- new_pkg_deps("pkgload")
    #' pd$resolve()
    #' pd$solve()
    #' pd$get_solution()

    get_solution = function() private$plan$get_solution(),

    #' @description
    #' Error if the dependency solver failed to find a consistent set of
    #' packages that can be installed together.
    #'
    #' @examplesIf pkgdepends:::is_online()
    #' # This is an error, because the packages conflict:
    #' pd <- new_pkg_deps(
    #'   c("r-lib/pak", "cran::pak"),
    #'   config = list(library = tempfile())
    #' )
    #' pd$resolve()
    #' pd$solve()
    #' pd
    #' # This fails:
    #' # pd$stop_for_solution_error()

    stop_for_solution_error = function() {
      private$plan$stop_for_solve_error()
    },

    #' @description
    #' Draw a tree of package dependencies. It returns a `tree` object, see
    #' [cli::tree()]. Printing this object prints the dependency tree to the
    #' screen.
    #'
    #' @return
    #' A `tree` object from the cli package, see [cli::tree()].
    #'
    #' @examplesIf pkgdepends:::is_online()
    #' pd <- new_pkg_deps("pkgload")
    #' pd$solve()
    #' pd$draw()

    draw = function() private$plan$draw_solution_tree(),

    #' @description
    #' Format a `pkg_deps` object, typically for printing.
    #'
    #' @param ... Not used currently.
    #'
    #' @return
    #' A character vector, each element should be a line in the printout.

    format = function(...) {
      refs <- private$plan$get_refs()

      has_res <- private$plan$has_resolution()
      res <- if (has_res) private$plan$get_resolution()
      res_err <- has_res && any(res$status != "OK")

      has_sol <- private$plan$has_solution()
      sol <- if (has_sol) private$plan$get_solution()
      sol_err <- has_sol && sol$status != "OK"

      deps <- if (has_res) length(unique(res$package[!res$direct]))

      c("<pkg_dependencies>",
        "+ refs:", paste0("  - ", refs),
        if (has_res) paste0("+ has resolution (+", deps, " dependencies)"),
        if (res_err) "x has resolution errors",
        if (has_sol) "+ has solution",
        if (sol_err) "x has solution errors",
        if (!has_res) "(use `$resolve()` to resolve dependencies)",
        if (has_res) "(use `$get_resolution()` to see resolution results)",
        if (!has_sol) "(use `$solve()` to solve dependencies)",
        if (has_sol) "(use `$get_solution()` to see solution results)",
        if (has_sol && !sol_err) "(use `$draw()` to draw the dependency tree)"
        )
    },

    #' @description
    #' Prints a `pkg_deps` object to the screen. The printout includes:
    #'
    #' * The package refs.
    #' * Whether the object has the resolved dependencies.
    #' * Whether the resolution had errors.
    #' * Whether the object has the solved dependencies.
    #' * Whether the solution had errors.
    #' * Advice on which methods to call next.
    #'
    #' See the example below.
    #'
    #' @param ... not used currently.
    #' @return
    #' The `pkg_deps` object itself, invisibly.
    #'
    #' @examplesIf pkgdepends:::is_online()
    #' pd <- new_pkg_deps("r-lib/pkgdepends")
    #' pd
    #'
    #' pd$resolve()
    #' pd
    #'
    #' pd$solve()
    #' pd

    print = function(...) {
      cat(self$format(...), sep = "\n")
      invisible(self)
    }
  ),

  private = list(
    plan = NULL,
     library = NULL
  )
)
