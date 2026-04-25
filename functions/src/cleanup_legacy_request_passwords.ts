import * as admin from "firebase-admin";

const allowedCollections = [
  "workspace_requests",
  "join_company_requests",
] as const;

type AllowedCollection = typeof allowedCollections[number];

interface CleanupOptions {
  apply: boolean;
  batchSize: number;
  collections: AllowedCollection[];
}

interface CleanupResult {
  collection: string;
  scanned: number;
  matched: number;
  updated: number;
}

/**
 * Prints command usage.
 */
function printHelp() {
  console.log(`
Cleanup legacy plain-text password fields from OTP request documents.

Usage:
  npm --prefix functions run cleanup:legacy-request-passwords
  npm --prefix functions run cleanup:legacy-request-passwords -- --apply

Options:
  --apply                 Actually delete password fields. Without this,
                          the script only reports what it would change.
  --batch-size=<number>   Documents to read per page. Default: 300.
  --collection=<name>     Limit to one collection. Allowed values:
                          workspace_requests, join_company_requests.
  --help                  Show this help.
`);
}

/**
 * Parses CLI arguments into cleanup options.
 * @param {string[]} argv raw process arguments
 * @return {CleanupOptions}
 */
function parseArgs(argv: string[]): CleanupOptions {
  const options: CleanupOptions = {
    apply: false,
    batchSize: 300,
    collections: [...allowedCollections],
  };

  for (const arg of argv) {
    if (arg === "--apply") {
      options.apply = true;
      continue;
    }

    if (arg === "--dry-run") {
      options.apply = false;
      continue;
    }

    if (arg === "--help" || arg === "-h") {
      printHelp();
      process.exit(0);
    }

    if (arg.startsWith("--batch-size=")) {
      const rawSize = arg.replace("--batch-size=", "").trim();
      const parsed = Number.parseInt(rawSize, 10);
      if (!Number.isFinite(parsed) || parsed < 1 || parsed > 500) {
        throw new Error("--batch-size must be between 1 and 500.");
      }
      options.batchSize = parsed;
      continue;
    }

    if (arg.startsWith("--collection=")) {
      const collection = arg.replace("--collection=", "").trim();
      if (!isAllowedCollection(collection)) {
        throw new Error(`Unsupported collection: ${collection}`);
      }
      options.collections = [collection];
      continue;
    }

    throw new Error(`Unknown argument: ${arg}`);
  }

  return options;
}

/**
 * Checks whether a collection name is allowed for this cleanup.
 * @param {string} collection Firestore collection name
 * @return {boolean}
 */
function isAllowedCollection(
  collection: string,
): collection is AllowedCollection {
  return allowedCollections.includes(collection as AllowedCollection);
}

/**
 * Scans one collection and deletes legacy password fields when requested.
 * @param {FirebaseFirestore.Firestore} db Firestore client
 * @param {AllowedCollection} collection collection to scan
 * @param {CleanupOptions} options cleanup options
 * @return {Promise<CleanupResult>}
 */
async function cleanupCollection(
  db: FirebaseFirestore.Firestore,
  collection: AllowedCollection,
  options: CleanupOptions,
): Promise<CleanupResult> {
  let scanned = 0;
  let matched = 0;
  let updated = 0;
  let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | undefined;
  let hasMore = true;

  while (hasMore) {
    let query = db
      .collection(collection)
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(options.batchSize);

    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snapshot = await query.get();
    if (snapshot.empty) {
      break;
    }

    scanned += snapshot.size;
    const docsWithPassword = snapshot.docs.filter((doc) => {
      return Object.prototype.hasOwnProperty.call(doc.data(), "password");
    });

    matched += docsWithPassword.length;

    if (options.apply && docsWithPassword.length > 0) {
      const batch = db.batch();
      for (const doc of docsWithPassword) {
        batch.update(doc.ref, {
          password: admin.firestore.FieldValue.delete(),
        });
      }
      await batch.commit();
      updated += docsWithPassword.length;
    }

    lastDoc = snapshot.docs[snapshot.docs.length - 1];
    hasMore = snapshot.size === options.batchSize;
  }

  return {
    collection,
    scanned,
    matched,
    updated,
  };
}

/**
 * Runs the cleanup.
 */
async function main() {
  const options = parseArgs(process.argv.slice(2));

  if (admin.apps.length === 0) {
    admin.initializeApp();
  }

  const db = admin.firestore();
  const projectId = admin.app().options.projectId ?? "default project";
  const mode = options.apply ? "APPLY" : "DRY RUN";

  console.log(`Legacy request password cleanup (${mode})`);
  console.log(`Project: ${projectId}`);
  console.log(`Collections: ${options.collections.join(", ")}`);

  const results: CleanupResult[] = [];
  for (const collection of options.collections) {
    const result = await cleanupCollection(db, collection, options);
    results.push(result);
    console.log(
      [
        collection,
        `scanned=${result.scanned}`,
        `matched=${result.matched}`,
        `updated=${result.updated}`,
      ].join(" "),
    );
  }

  const totals = results.reduce(
    (acc, result) => {
      acc.scanned += result.scanned;
      acc.matched += result.matched;
      acc.updated += result.updated;
      return acc;
    },
    {scanned: 0, matched: 0, updated: 0},
  );

  console.log(
    [
      "Total",
      `scanned=${totals.scanned}`,
      `matched=${totals.matched}`,
      `updated=${totals.updated}`,
    ].join(" "),
  );

  if (!options.apply) {
    console.log("Dry run only. Re-run with --apply to delete fields.");
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
