#include "counting_tracker.h"

#include <algorithm>
#include <utility>

namespace beenut {

CountingTracker::CountingTracker(CountingConfig config)
    : config_(std::move(config))
{
}

void CountingTracker::reload(CountingConfig config)
{
    config_ = std::move(config);
    reset();
}

void CountingTracker::reset()
{
    samples_.clear();
    locked_ = {};
    lastSampleAt_.invalidate();
}

CountingSnapshot CountingTracker::update(bool trayPresent, const InferenceResult& result)
{
    if (!trayPresent) {
        reset();
        return locked_;
    }

    if (lastSampleAt_.isValid() && lastSampleAt_.elapsed() > timeoutMs()) {
        samples_.clear();
        locked_ = {};
    }
    lastSampleAt_.restart();

    samples_.append({
        .count = result.count,
        .detections = result.detections,
        .processingMs = result.processingMs,
    });
    while (samples_.size() > stableFrames()) {
        samples_.removeFirst();
    }

    if (samples_.size() >= stableFrames()) {
        locked_ = lockFromSamples();
    } else {
        locked_.samples = samples_.size();
    }
    return locked_;
}

CountingSnapshot CountingTracker::snapshot() const
{
    return locked_;
}

int CountingTracker::stableFrames() const
{
    return std::max(1, config_.stableFrames);
}

int CountingTracker::timeoutMs() const
{
    return std::max(100, config_.timeoutMs);
}

CountingSnapshot CountingTracker::lockFromSamples()
{
    QVector<int> counts;
    counts.reserve(samples_.size());
    for (const auto& sample : samples_) {
        counts.append(sample.count);
    }
    std::sort(counts.begin(), counts.end());
    // Use the lower median for even windows so noisy high frames do not
    // over-count small parts while the tray is settling.
    const int medianIndex = (counts.size() - 1) / 2;
    const int medianCount = counts.at(medianIndex);

    const auto it = std::find_if(samples_.crbegin(), samples_.crend(), [&](const Sample& sample) {
        return sample.count == medianCount;
    });

    CountingSnapshot snapshot;
    snapshot.count = medianCount;
    snapshot.locked = true;
    snapshot.samples = samples_.size();
    if (it != samples_.crend()) {
        snapshot.detections = it->detections;
    }
    return snapshot;
}

}  // namespace beenut
