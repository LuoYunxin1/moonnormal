///|
fn attribute_text(
  owner : Schema,
  attrs : Array[Int32],
) -> String raise DesignError {
  "{" + owner.names(attrs).join(", ") + "}"
}

///|
fn dependency_text(owner : Schema, fd : FD) -> String raise DesignError {
  attribute_text(owner, fd.left) + " -> " + attribute_text(owner, fd.right)
}

///|
fn form_text(form : NormalForm) -> String {
  match form {
    Second => "2NF"
    Third => "3NF"
    BoyceCodd => "BCNF"
  }
}

///|
pub fn Schema::plan_report(
  self : Schema,
  plan : Plan,
  limits~ : Limits = default_limits(),
) -> String raise DesignError {
  let parts = self.fragments(plan.relations, true)
  let audit = self.audit_plan(plan, limits~)
  let locality = self.dependency_locality(parts, limits~)
  let out = StringBuilder()
  out.write_string("Target: " + form_text(plan.target) + "\n")
  out.write_string(
    "Lossless under declared FDs: " + audit.lossless.to_string() + "\n",
  )
  out.write_string(
    "Dependency preserving: " + audit.dependency_preserving.to_string() + "\n",
  )
  out.write_string(
    "Target satisfied: " + audit.target_satisfied.to_string() + "\n",
  )
  for i in 0..<parts.length() {
    out.write_string(
      "Relation " + i.to_string() + ": " + attribute_text(self, parts[i]) + "\n",
    )
  }
  for fd in audit.missing_dependencies {
    out.write_string("Not preserved: " + dependency_text(self, fd) + "\n")
  }
  for violation in audit.violations {
    out.write_string(
      "Violation in " +
      attribute_text(self, violation.relation) +
      ": " +
      dependency_text(self, violation.dependency) +
      "\n",
    )
  }
  for item in locality {
    if item.containing_relations.is_empty() {
      out.write_string(
        "Cross-relation dependency: " +
        dependency_text(self, item.dependency) +
        "\n",
      )
    }
  }
  out.write_string(
    "These claims are relative to declared FDs, not inferred from observed tuples.\n",
  )
  out.to_string()
}

///|
pub fn Table::audit_report(
  self : Table,
  owner : Schema,
  limits~ : Limits = default_limits(),
) -> String raise DesignError {
  let audit = self.audit_dependencies(owner, limits~)
  let profiles = self.column_profiles(limits~)
  let fds = owner.dependencies()
  let out = StringBuilder()
  out.write_string(
    "Set-valued observed rows: " + self.row_count().to_string() + "\n",
  )
  out.write_string(
    "Checked declared dependencies: " +
    audit.checked_dependencies.length().to_string() +
    "\n",
  )
  out.write_string(
    "Skipped dependencies lacking columns: " +
    audit.skipped_dependencies.length().to_string() +
    "\n",
  )
  for witness in audit.violations {
    out.write_string(
      "Rows " +
      witness.first_row.to_string() +
      " and " +
      witness.second_row.to_string() +
      " violate " +
      dependency_text(owner, fds[witness.dependency_index]) +
      "; differ on " +
      attribute_text(owner, witness.differing_attributes) +
      "\n",
    )
  }
  for profile in profiles {
    out.write_string(
      "Column " +
      owner.labels[profile.attribute] +
      ": distinct=" +
      profile.distinct_values.to_string() +
      ", empty=" +
      profile.empty_values.to_string() +
      ", max-code-units=" +
      profile.maximum_code_units.to_string() +
      "\n",
    )
  }
  out.write_string(
    "Row indices refer to deduplicated input order; empty strings are ordinary values.\n",
  )
  out.write_string(
    "No violations observed does not establish a universal functional dependency.\n",
  )
  out.to_string()
}

///|
pub fn MigrationReview::summary(
  self : MigrationReview,
  owner : Schema,
) -> String raise DesignError {
  let out = StringBuilder()
  out.write_string(
    "Lossless regression: " + self.lossless_regression.to_string() + "\n",
  )
  out.write_string(
    "Normal-form regression: " + self.normal_form_regression.to_string() + "\n",
  )
  for fd in self.lost_dependencies {
    out.write_string("Lost preservation: " + dependency_text(owner, fd) + "\n")
  }
  for fd in self.gained_dependencies {
    out.write_string(
      "Gained preservation: " + dependency_text(owner, fd) + "\n",
    )
  }
  for relation in self.layout.removed {
    out.write_string("Remove: " + attribute_text(owner, relation) + "\n")
  }
  for relation in self.layout.added {
    out.write_string("Add: " + attribute_text(owner, relation) + "\n")
  }
  out.write_string(
    "Review aid only; does not authorize or execute a database migration.\n",
  )
  out.to_string()
}
