export const GUIDE_PAGES = {
  "clear-system-data-mac": {
    title: "System Data on Mac is huge — what that actually means",
    description:
      "System Data is a Storage bucket, not one folder. DiskPrune shows what it can measure, inspects APFS snapshots, and does not flush them.",
    sections: [
      {
        h2: "System Data is a label, not a directory",
        p: [
          "macOS Settings → General → Storage groups a pile of things under “System Data”: caches, logs, swap, Spotlight, local Time Machine snapshots, virtual machine images, and files Apple does not classify as Apps, Documents, Photos, or iCloud. The number is large because the bucket is wide, not because one junk folder is hiding.",
          "A cleaner that promises to “clear System Data instantly” is selling a bucket name. DiskPrune does not. It scans what it is allowed to see, classes what it knows, and leaves a not-examined region when it cannot look.",
        ],
      },
      {
        h2: "What DiskPrune will plan",
        p: [
          "User-level caches, package-manager leftovers, Xcode DerivedData, and logs can appear as Safe or Review candidates after a scan. You select them. DiskPrune builds a plan, shows a dry run, re-checks the path, and moves approved items to Trash. It does not empty Trash.",
          "Space occupied by those files becomes available after you empty Trash in Finder — not at the moment of the move.",
        ],
      },
      {
        h2: "What DiskPrune will only inspect",
        p: [
          "APFS local snapshots often sit inside the System Data number. DiskPrune lists snapshots on the Snapshots screen. There is no delete control. DiskPrune does not run snapshot deletion, and it will not print a delete command for you to paste.",
          "If you want snapshots gone, that is an OS / Time Machine decision, documented by Apple. It is not a DiskPrune feature, and it is not something we will add by putting a red button on that list.",
        ],
      },
      {
        h2: "What DiskPrune will not touch",
        p: [
          "Docker.raw and Docker data directories are protected. They can look like tens of gigabytes of System Data. Deleting the image from a cleaner is how people lose containers. Compact it with Docker itself; see the Docker guide.",
        ],
      },
    ],
  },
  "how-to-delete-xcode-deriveddata": {
    title: "How to clear Xcode DerivedData without a terminal ritual",
    description:
      "DerivedData is rebuildable build product. DiskPrune names it, classes it, and will move it to Trash only after a dry run.",
    sections: [
      {
        h2: "Where it lives",
        p: [
          "Xcode writes intermediate build products, indexes, and module caches under ~/Library/Developer/Xcode/DerivedData (and a related ModuleCache). On a machine that builds often, this tree is routinely several gigabytes. It is not your source. Xcode recreates it the next time you build.",
        ],
      },
      {
        h2: "What “delete” should mean",
        p: [
          "The internet still tells people to rm -rf that folder. That works until it does not — wrong path, a symlink, a folder that is not DerivedData. DiskPrune’s Xcode probe names DerivedData as a known location, classes it as a cleanup candidate, and will only move it to Trash after you select it, confirm a dry run, and pass the pre-trash checks.",
          "Files stay in Trash until you empty it. If a build needed that cache, restore from Trash and rebuild.",
        ],
      },
      {
        h2: "What DiskPrune will not do here",
        p: [
          "It will not skip the dry run. It will not permanently delete. It will not treat an .app bundle inside Developer tools as a candidate. Scan is free; moving DerivedData to Trash requires the $19 lifetime license.",
        ],
      },
    ],
  },
  "shrink-docker-disk-mac": {
    title: "Docker.raw is huge on Mac — and DiskPrune will not delete it",
    description:
      "Docker Desktop stores a sparse APFS disk image. DiskPrune marks Docker.raw as protected. Compact it with Docker, not with a cleaner.",
    sections: [
      {
        h2: "Why Finder lies about the size",
        p: [
          "Docker Desktop on Mac keeps a virtual disk, often named Docker.raw (or a .img in ~/Library/Containers/com.docker.docker). It is a sparse image. Logical size can read as 64 GB while size on disk is smaller — or the reverse after layers pile up. Either way, a generic “delete large files” pass is the wrong tool.",
        ],
      },
      {
        h2: "Protected on purpose",
        p: [
          "DiskPrune’s Docker probe can see the image. It cannot select it. There is no checkbox. Cleanup plans reject it. That is not a missing feature. Deleting Docker.raw from a storage app is how images, volumes, and a working Docker install disappear.",
        ],
      },
      {
        h2: "How to actually shrink it",
        p: [
          "Use Docker for the unused layers: docker system prune (and docker builder prune if you use BuildKit). In Docker Desktop, Troubleshoot includes a disk-image / clean path. After unused layers are gone, Docker can compact the image. Then DiskPrune’s next scan will show a smaller Developer / other contribution — it will still not offer to trash the image.",
          "If you do not use Docker, uninstall Docker Desktop from Docker’s own uninstaller, not by trashing a random raw file.",
        ],
      },
    ],
  },
  "delete-purgeable-space-mac": {
    title: "Purgeable space and APFS snapshots on Mac",
    description:
      "Purgeable is APFS speaking. Local snapshots are a common reason System Data looks huge. DiskPrune lists snapshots and does not delete them.",
    sections: [
      {
        h2: "Purgeable is not a junk folder",
        p: [
          "APFS reports some used space as purgeable: clones, snapshots, and files macOS believes it can recover if you need the room. Finder’s “available” number already bakes some of that in. A button that claims to “delete purgeable space” is usually either emptying Trash, deleting local snapshots, or lying.",
        ],
      },
      {
        h2: "Snapshots are inspect-only",
        p: [
          "Time Machine local snapshots are the usual surprise. DiskPrune lists them on Snapshots. There is no swipe-to-delete, no checkbox, no tmutil command in the UI. We do not run snapshot deletion, and we will not add it.",
          "Apple documents how local snapshots work. If you turn Time Machine off, or let the system expire snapshots under space pressure, that is macOS. DiskPrune’s job is to show they exist so “System Data” is not a mystery.",
        ],
      },
      {
        h2: "What you can do in DiskPrune today",
        p: [
          "Scan. Read the autopsy. Move caches, logs, and DerivedData you actually selected to Trash. Empty Trash in Finder when you mean it. If the capacity bar barely moves, look at Snapshots and Docker — those are the two places DiskPrune refuses to pretend.",
        ],
      },
    ],
  },
};
