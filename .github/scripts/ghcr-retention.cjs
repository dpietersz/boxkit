// GHCR retention for toolbox images. Used by .github/workflows/cleanup-ghcr.yml.
//
// Every release pushes TWO package versions per image: the image manifest
// (tagged vX.Y.Z / latest) and a cosign signature manifest (tagged
// sha256-<image-digest>.sig). Counting raw versions would therefore prune
// real images while keeping their signatures, so retention is image-based:
//   - keep the `keep` newest tagged images, plus any image tagged `latest`
//   - keep cosign artifacts (.sig/.att/.sbom) only for kept images
//   - never delete untagged versions (could be manifest-list children)

const ARTIFACT_TAG = /^sha256-([0-9a-f]{64})\.(sig|att|sbom)$/;

const tagsOf = (version) => version.metadata?.container?.tags ?? [];

function planRetention(versions, keep) {
  const images = [];
  const artifacts = [];
  const untagged = [];
  for (const version of versions) {
    const tags = tagsOf(version);
    if (tags.length === 0) untagged.push(version);
    else if (tags.every((tag) => ARTIFACT_TAG.test(tag))) artifacts.push(version);
    else images.push(version);
  }

  images.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
  const keptImages = images.filter(
    (image, index) => index < keep || tagsOf(image).includes("latest"),
  );
  const keptDigests = new Set(keptImages.map((image) => image.name));
  const isForKeptImage = (artifact) =>
    tagsOf(artifact).some((tag) =>
      keptDigests.has(`sha256:${tag.match(ARTIFACT_TAG)[1]}`),
    );

  const keptArtifacts = artifacts.filter(isForKeptImage);
  return {
    keep: [...keptImages, ...keptArtifacts, ...untagged],
    remove: [
      ...images.filter((image) => !keptImages.includes(image)),
      ...artifacts.filter((artifact) => !keptArtifacts.includes(artifact)),
    ],
  };
}

async function prune({ github, context, core, packageNames, keep, dryRun }) {
  const owner = context.repo.owner;
  const { data: account } = await github.rest.users.getByUsername({
    username: owner,
  });
  const organization = account.type === "Organization";
  const ownerParams = organization ? { org: owner } : { username: owner };
  const listVersions = organization
    ? github.rest.packages.getAllPackageVersionsForPackageOwnedByOrg
    : github.rest.packages.getAllPackageVersionsForPackageOwnedByUser;
  const deleteVersion = organization
    ? github.rest.packages.deletePackageVersionForOrg
    : github.rest.packages.deletePackageVersionForUser;

  for (const packageName of packageNames) {
    const packageParams = {
      ...ownerParams,
      package_type: "container",
      package_name: packageName,
    };
    let versions;
    try {
      versions = await github.paginate(listVersions, {
        ...packageParams,
        per_page: 100,
      });
    } catch (error) {
      if (error.status === 404) {
        core.warning(`${packageName}: package not published yet, skipping`);
        continue;
      }
      throw error;
    }

    const { keep: kept, remove } = planRetention(versions, keep);
    core.info(
      `${packageName}: keeping ${kept.length} of ${versions.length} versions, removing ${remove.length}`,
    );
    for (const version of remove) {
      const tags = tagsOf(version).join(",") || "untagged";
      core.info(
        `${dryRun ? "Would delete" : "Deleting"} ${packageName} ${version.id} (${tags})`,
      );
      if (!dryRun) {
        await deleteVersion({ ...packageParams, package_version_id: version.id });
      }
    }
  }
}

module.exports = { planRetention, prune };
