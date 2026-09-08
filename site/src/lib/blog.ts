export type Guide = {
  slug: string;
  title: string;
  desc: string;
  minutes: number;
  body: { heading: string; paragraphs: string[] }[];
};

export const GUIDES: Guide[] = [
  {
    slug: "clear-system-data-mac",
    title: "Clear System Data on Mac",
    desc: "Why System Data balloons on Sonoma and Sequoia, and how to reclaim it without wiping the wrong folders.",
    minutes: 6,
    body: [
      {
        heading: "What System Data actually is",
        paragraphs: [
          "macOS Storage settings lumps caches, logs, Time Machine local snapshots, iOS backups, VM swap, and developer artifacts into a single “System Data” bar. That bar is not one folder you can empty. It is the remainder after Photos, Apps, and Documents are counted.",
          "On developer machines the usual culprits are Xcode DerivedData, Docker’s virtual disk, npm and Gradle caches, and APFS local snapshots that Time Machine keeps even when no backup disk is attached.",
        ],
      },
      {
        heading: "Do this before deleting anything",
        paragraphs: [
          "Open System Settings → General → Storage and wait for the categories to finish calculating. Note the System Data size. Then check whether Time Machine local snapshots are present: in Terminal, run tmutil listlocalsnapshots /.",
          "If snapshots exist, they often account for 10–40 GB of “purgeable” space that Finder will not show as free until they are deleted. DiskPrune’s purge path calls tmutil deletelocalsnapshots / after moving selected files to Trash.",
        ],
      },
      {
        heading: "Safe manual targets",
        paragraphs: [
          "User caches at ~/Library/Caches, logs at ~/Library/Logs, and Xcode’s DerivedData are the same Tier 1 paths DiskPrune scans automatically. They rebuild themselves. Do not empty ~/Library/Application Support or ~/Library/Containers without reviewing folder names — those hold live app databases.",
          "After clearing caches, empty Trash and give Spotlight a minute. Storage settings can lag; df -h in Terminal is the honest number.",
        ],
      },
    ],
  },
  {
    slug: "how-to-delete-xcode-deriveddata",
    title: "How to Delete Xcode DerivedData",
    desc: "Safely clear Xcode DerivedData, ModuleCache, and Archives leftovers that quietly eat tens of gigabytes.",
    minutes: 5,
    body: [
      {
        heading: "Where DerivedData lives",
        paragraphs: [
          "Xcode writes intermediate build products, indexes, and module caches to ~/Library/Developer/Xcode/DerivedData. Each project gets a folder with a random suffix (DiskPrune-ekqjxw). A year of switching branches can leave 10–30 GB here even if you only keep a few apps.",
          "This is DiskPrune’s largest default Tier 1 target. The native scanner enumerates the folder with FileManager and later moves selected items to Trash — it does not rm -rf.",
        ],
      },
      {
        heading: "Manual clear",
        paragraphs: [
          "Quit Xcode first. In Finder, Go → Go to Folder and paste ~/Library/Developer/Xcode/DerivedData. Delete the project folders you no longer need, or the whole directory. Xcode recreates it on the next build.",
          "You can also run rm -rf ~/Library/Developer/Xcode/DerivedData from Terminal. Prefer Trash if you want an undo. Afterward, delete ModuleCache.noindex if it remains — stale module caches cause more “clean build folder” rituals than they save.",
        ],
      },
      {
        heading: "What not to delete",
        paragraphs: [
          "~/Library/Developer/Xcode/Archives holds App Store archives. Those are not DerivedData. ~/Library/Developer/CoreSimulator/Devices holds simulator runtimes and app data; wiping devices is separate from DerivedData and will reset simulator state.",
          "If a single project’s DerivedData is huge, check whether you are copying resources into every build. DiskPrune will still reclaim the folder; fixing the project stops it coming back.",
        ],
      },
    ],
  },
  {
    slug: "shrink-docker-disk-mac",
    title: "Shrink Docker Disk on Mac",
    desc: "Reclaim storage from Docker Desktop’s raw disk image without uninstalling Docker.",
    minutes: 7,
    body: [
      {
        heading: "Why Docker.raw is enormous",
        paragraphs: [
          "Docker Desktop for Mac stores the Linux VM in a sparse APFS file, usually ~/.docker/desktop/vms/0/data/Docker.raw. The file grows as you pull images and almost never shrinks on its own. 20–60 GB is common on a machine that has built a handful of Node and Postgres images.",
          "DiskPrune lists ~/.docker/desktop as a Tier 2 path — review required. Deleting the raw file while Docker is running will corrupt the VM. The safe sequence is prune inside Docker, then compact, then consider removing unused data.",
        ],
      },
      {
        heading: "Prune, then compact",
        paragraphs: [
          "Quit running containers you do not need. Then: docker system prune -a --volumes. The -a flag removes unused images, not just dangling ones. Confirm you do not need those images before you type y.",
          "In Docker Desktop, go to Settings → Resources → Advanced (or Troubleshoot → Clean / Purge data on older builds) and compact the disk. On the command line, some versions support a factory reset from the whale menu. After compacting, the .raw file should drop to match actual usage.",
        ],
      },
      {
        heading: "If you just want the space back",
        paragraphs: [
          "Quit Docker Desktop completely (whale menu → Quit). Then the folder is safe to send to Trash — DiskPrune’s purge uses trashItem, so you can restore it. Reinstalling Docker recreates a fresh disk image.",
          "Do not delete ~/Library/Containers/com.docker.docker while the app is running. That is live container state, which is why it sits in Tier 2 next to Application Support.",
        ],
      },
    ],
  },
  {
    slug: "delete-purgeable-space-mac",
    title: "Delete Purgeable Space on Mac",
    desc: "Force macOS to release APFS purgeable space and local Time Machine snapshots.",
    minutes: 6,
    body: [
      {
        heading: "Purgeable is not free",
        paragraphs: [
          "Finder’s “available” number includes purgeable space — local snapshots, iCloud-optimized files, and system caches macOS would drop under pressure. Until it actually drops them, installs fail and Xcode complains about disk space you thought you had.",
          "The native DiskPrune scanner does not invent a new filesystem. After trashing selected files it calls tmutil deletelocalsnapshots /, the same APFS flush the GitHub Actions–built Mac app ships. That is the feature the comparison table calls out against DissectMac and Disk Buddy.",
        ],
      },
      {
        heading: "Flush local snapshots",
        paragraphs: [
          "List them: tmutil listlocalsnapshots /. Delete one by date: tmutil deletelocalsnapshots 2026-09-07-101500. Delete all: tmutil deletelocalsnapshots /. On Sequoia this may ask for an admin password; the Swift app surfaces a warning if tmutil exits non-zero.",
          "If snapshots immediately return, Time Machine is still on with “Back Up Automatically.” That is expected — macOS recreates localsnapshots as a safety net. Pause backups if you need the space to stay free.",
        ],
      },
      {
        heading: "The rest of purgeable",
        paragraphs: [
          "Empty Trash. Turn off optimized iCloud storage only if you understand it will re-download originals. Avoid random “clean my Mac” rm scripts against /System/Volumes/Data — that is how people brick a Mac.",
          "DiskPrune’s contract is narrow on purpose: Tier 1 caches, reviewed Tier 2 folders, then an APFS snapshot flush. Scan is free. Purging is the $19 lifetime license, stored in the Keychain on the native app.",
        ],
      },
    ],
  },
];

export function getGuide(slug: string): Guide | undefined {
  return GUIDES.find((g) => g.slug === slug);
}
